import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_audio/aaroha_audio.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../audio/audio_service.dart';
import '../audio/sound_delay.dart';
import '../data/content.dart';
import '../data/database.dart';
import '../data/history.dart';
import '../data/phrase_level.dart';
import '../data/providers.dart';
import '../data/tunes.dart';
import '../widgets/beat_strip.dart';
import 'practice_settings.dart';
import 'session_recorder.dart';

/// The round loop from docs/04-architecture.md:
/// calling → listening → verdict → (retry | replay | next) … → finished.
/// `answering`: Listen & name, waiting for taps (instead of `listening`).
enum PracticePhase { starting, calling, listening, answering, verdict, paused, finished, error }

class RoundRecord {
  RoundRecord(this.number, this.phrase, [this.label]) : target = phrase.pitches;
  final int number;

  /// The target with its written timing, as the call plays it (docs/08 M3-A).
  final Phrase phrase;

  /// The target's swars in order, which are judged.
  final List<Pitch> target;

  /// What the target is, in alankar and raga practice ("Aaroh", "Pakad").
  final String? label;
  final attempts = <AttemptResult>[];

  /// The pitch trace of each played attempt (docs/05 §10), shown after its
  /// verdict. Empty when naming.
  final traces = <PitchTrace>[];
  int? id;

  /// The player hit the give-up limit and the answer was revealed (M2-A).
  bool gaveUp = false;

  int get misses => attempts.where((a) => !a.passed).length;

  bool get firstTryPassed => attempts.isNotEmpty && attempts.first.passed;
  bool get passed => attempts.any((a) => a.passed);
}

/// Phases a session can be paused from: not while it is setting up, nor
/// once it has ended.
bool canPause(PracticePhase phase) => switch (phase) {
  PracticePhase.calling ||
  PracticePhase.listening ||
  PracticePhase.answering ||
  PracticePhase.verdict => true,
  _ => false,
};

enum ResumeStep { replayCall, nextRound }

/// What resuming a paused session does: a round still being worked on starts
/// again from its call (the player has lost the thread); one already passed
/// or given up moves on to the next.
ResumeStep resumeStep(RoundRecord? round) =>
    round == null || round.passed || round.gaveUp ? ResumeStep.nextRound : ResumeStep.replayCall;

class PracticeState {
  const PracticeState({
    required this.phase,
    required this.flute,
    required this.settings,
    required this.rounds,
    this.level = 0,
    this.message,
    this.countdown,
    this.answers = const [],
    this.keypad = const [],
    this.title,
    this.phraseLevel,
    this.timingNote,
  });

  final PracticePhase phase;
  final Flute flute;
  final PracticeSettings settings;
  final List<RoundRecord> rounds;

  /// Mic loudness 0..1 for the listening meter.
  final double level;
  final String? message;

  /// Seconds left before an automatic retry; null when none is running.
  final int? countdown;

  /// Listen & name: the swars tapped so far in this attempt.
  final List<Pitch> answers;

  /// Listen & name: the swars the keypad offers.
  final List<Pitch> keypad;

  /// What is being practised, in alankar and raga modes ("Yaman").
  final String? title;

  /// The phrase level in use (docs/05 §9); null in single-swar and rhythm
  /// practice.
  final int? phraseLevel;

  /// Rhythm practice: why timing isn't judged this session (headphones,
  /// Bluetooth), or null when it is.
  final String? timingNote;

  RoundRecord? get round => rounds.isEmpty ? null : rounds.last;
  AttemptResult? get lastResult => round?.attempts.lastOrNull;

  /// [message] and [countdown] are not carried over: any other update clears
  /// them.
  PracticeState copyWith({
    PracticePhase? phase,
    double? level,
    String? message,
    int? countdown,
    List<Pitch>? answers,
  }) => PracticeState(
    phase: phase ?? this.phase,
    flute: flute,
    settings: settings,
    rounds: rounds,
    level: level ?? this.level,
    message: message,
    countdown: countdown,
    answers: answers ?? this.answers,
    keypad: keypad,
    title: title,
    phraseLevel: phraseLevel,
    timingNote: timingNote,
  );
}

/// Where a session's targets come from, and what goes with them.
typedef PracticeMaterial = ({
  Raga? raga,
  int? rounds,
  List<Pitch> keypad,
  String? title,
  Taal? taal,
});

int _byPitch(Pitch a, Pitch b) =>
    (a.octave * 12 + a.swar.semitone).compareTo(b.octave * 12 + b.swar.semitone);

final practiceProvider = NotifierProvider<PracticeController, PracticeState?>(
  PracticeController.new,
);

class PracticeController extends Notifier<PracticeState?> {
  StreamSubscription<List<PitchFrame>>? _frames;
  Timer? _advance;
  Timer? _countdown;
  Timer? _phaseTimer;
  final _answers = <Pitch>[];
  late Drill Function() _nextDrill;
  PracticeHistory? _history;

  // Phrase length (docs/05 §9): the level in use, and its tracker when the
  // level grows with the player (null when it's held).
  int _level = 1;
  PhraseLevelTracker? _levelTracker;
  RagaDrill? _ragaDrill;
  TuneDrill? _tuneDrill;
  int? _sessionId;
  SessionRecorder? _recorder;

  // The call being played, to measure its round trip (decisions.md D28).
  int _callStart = 0;
  int _callEnd = 0;
  double _callHz = 0;
  bool _callMeasured = true;

  static const _loopbackKey = 'loopback_ms';

  /// After the call's echo has passed, wait this much more before listening:
  /// the voice's release plus the room.
  static const _afterEchoMs = 150;

  // Listening window, in engine frames.
  ListenWindow? _window;
  int get _listenFrom => _window?.from ?? 0;
  int get _deadline => _window?.deadline ?? 0;
  final _heard = <PitchFrame>[];

  /// Rhythm practice: the sams the player may start on in this turn (engine
  /// frames, as scheduled), and the sound delay to time notes with (D45):
  /// null when timing isn't judged.
  var _sams = <int>[];
  double? _timingDelayMs;
  bool _timing = false;

  /// The clicks of the current call or retry, for the beat strip.
  BeatPlan _beats = BeatPlan.none;
  BeatPlan get beats => _beats;

  /// The engine time the player is hearing now. The click reaches the mic
  /// one round trip after it was played; the strip lights it then, a little
  /// after the ear hears it (by the mic's share of the delay), since a light
  /// slightly late looks in time and one early doesn't.
  int heardTime() => _audio.time - _audio.loopbackFrames;

  AudioService get _audio => ref.read(audioServiceProvider);
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  PracticeState? build() {
    ref.onDispose(_cleanUp);
    return null;
  }

  Future<void> start(Flute flute, PracticeSettings settings) async {
    _cleanUp();
    state = PracticeState(
      phase: PracticePhase.starting,
      flute: flute,
      settings: settings,
      rounds: [],
    );
    // Smart drilling learns from every earlier first try (docs/05 §8).
    _history = settings.adaptive ? await loadPracticeHistory(_db) : null;
    _levelTracker = null;
    _ragaDrill = null;
    _tuneDrill = null;
    final rhythm = settings.mode == PracticeMode.rhythm;
    if (settings.mode != PracticeMode.single && !rhythm) {
      if (settings.phraseLevelGrows) {
        _levelTracker = await loadPhraseLevel(_db, naming: settings.naming);
        _level = _levelTracker!.level;
      } else {
        _level = settings.phraseLevel;
      }
    }
    final PracticeMaterial m;
    try {
      m = await _material(flute, settings);
    } on Object catch (e) {
      state = state!.copyWith(phase: PracticePhase.error, message: '$e');
      return;
    }
    final raga = m.raga;
    // An alankar is one walk up and down: it sets its own number of rounds.
    if (m.rounds != null) settings = settings.copyWith(rounds: m.rounds);
    // Rhythm practice clicks every matra, in its lesson's taal.
    if (m.taal != null) settings = settings.copyWith(metronome: true, taalId: m.taal!.id);
    String? timingNote;
    _timing = rhythm;
    _timingDelayMs = null;
    if (rhythm) {
      // Timing needs the sound's round trip: measured on the speaker only.
      final route = await currentOutputRoute();
      if (route.measurable) {
        final raw = await _db.setting(SoundDelay.key(route));
        _timingDelayMs = SoundDelay.fromJson(route, raw)?.ms;
      } else {
        _timing = false;
        timingNote = route == OutputRoute.bluetooth
            ? 'Timing isn\'t judged on Bluetooth: its delay is too long and uneven.'
            : 'Timing isn\'t judged with headphones yet: play through the phone speaker for it.';
      }
    }
    state = PracticeState(
      phase: PracticePhase.starting,
      flute: flute,
      settings: settings,
      rounds: [],
      keypad: m.keypad,
      title: m.title,
      phraseLevel: settings.mode == PracticeMode.single || rhythm ? null : _level,
      timingNote: timingNote,
    );
    _audio.configureFor(flute.saHz);
    _audio.setDrone(
      saHz: flute.saHz,
      firstString: switch (raga?.drone) {
        Swar.ma => DroneFirstString.ma,
        Swar.ni => DroneFirstString.ni,
        _ => DroneFirstString.pa,
      },
      volume: settings.droneVolume,
      on: settings.droneOn,
    );
    // Listen & name needs no mic: the engine runs playback only.
    if (!await _audio.ensureStarted(capture: !settings.naming)) {
      state = state!.copyWith(
        phase: PracticePhase.error,
        message: 'The microphone is not available (${_audio.status.name}).',
      );
      return;
    }
    final savedLoopback = double.tryParse(await _db.setting(_loopbackKey) ?? '');
    if (savedLoopback != null) _audio.restoreLoopback(savedLoopback);
    _frames = _audio.frames.listen(_onFrames);
    _sessionId = await _db
        .into(_db.sessions)
        .insert(
          SessionsCompanion.insert(
            fluteId: flute.id,
            mode: settings.mode.name,
            settingsJson: jsonEncode(settings.toJson()),
            saHz: flute.saHz,
            startedAt: DateTime.now(),
          ),
        );
    if (settings.saveSessionAudio && !settings.naming) {
      _recorder = SessionRecorder(_audio);
      await _recorder!.start(flute.name, _sessionId!, {
        'sessionId': _sessionId,
        'flute': flute.name,
        'saHz': flute.saHz,
        'settings': settings.toJson(),
      });
    }
    await _nextRound();
  }

  /// Sets up where targets come from (docs/06, content for each mode).
  Future<PracticeMaterial> _material(Flute flute, PracticeSettings settings) async {
    final tuning = settings.tuning.tuning;
    switch (settings.mode) {
      case PracticeMode.single || PracticeMode.phrase:
        final history = _history;
        final pitches = practicePitches(
          settings.swarSet,
          settings.range,
          low: flute.low,
          high: flute.high,
        );
        final targets = TargetGenerator(
          pitches,
          weightOf: history?.weight,
          pairs: history == null ? null : () => history.confusedPairs(),
        );
        final single = settings.mode == PracticeMode.single;
        _nextDrill = () => (
          label: '',
          phrase: evenPhrase(
            single
                ? targets.single()
                : targets.phrase(
                    minLength: PhraseLevel.minNotes(_level),
                    maxLength: PhraseLevel.maxNotes(_level),
                  ),
          ),
        );
        return (raga: null, rounds: null, keypad: pitches, title: null, taal: null);
      case PracticeMode.alankar:
        final content = await ref.read(contentProvider.future);
        final alankar = content.alankar(settings.alankarId) ?? content.alankars.first;
        final raga = settings.ragaInUse == null ? null : content.raga(settings.ragaInUse!);
        final set = SwarSet.values.where((s) => s.name == settings.alankarScale).firstOrNull;
        List<Pitch> degrees(Iterable<Swar> swars) =>
            scaleDegrees(swars, settings.range, low: flute.low, high: flute.high, tuning: tuning);
        final up = degrees(raga?.aarohSwars ?? (set ?? SwarSet.shuddha).swars);
        final down = degrees(raga?.avarohSwars ?? (set ?? SwarSet.shuddha).swars);
        // The level at the start holds for the whole walk.
        final rounds = alankarRounds(alankar, up, down, maxNotes: PhraseLevel.maxNotes(_level));
        if (rounds.isEmpty) throw StateError('This alankar does not fit the flute\'s range.');
        var i = 0;
        _nextDrill = () => rounds[i++ % rounds.length];
        return (
          raga: raga,
          rounds: rounds.length,
          keypad: {...up, ...down}.toList()..sort(_byPitch),
          title: '${alankar.name} · ${raga?.name ?? (set ?? SwarSet.shuddha).label}',
          taal: null,
        );
      case PracticeMode.raga:
        final content = await ref.read(contentProvider.future);
        final raga = content.raga(settings.ragaId) ?? content.ragas.first;
        final drill = _ragaDrill = RagaDrill(
          raga,
          low: flute.low,
          high: flute.high,
          tuning: tuning,
          maxNotes: PhraseLevel.maxNotes(_level),
        );
        _nextDrill = drill.next;
        return (
          raga: raga,
          rounds: null,
          keypad: scaleDegrees(
            raga.swars,
            SaptakRange.all,
            low: flute.low,
            high: flute.high,
            tuning: tuning,
          ),
          title: raga.name,
          taal: null,
        );
      case PracticeMode.tune:
        // The chosen tune, or the newest that parses (D56).
        final stored = await (_db.select(
          _db.tunes,
        )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
        final candidates = [
          for (final t in stored)
            if (t.parsed != null) t,
        ];
        final pick =
            candidates.where((t) => t.id == settings.tuneId).firstOrNull ?? candidates.firstOrNull;
        if (pick == null) throw StateError('Add a tune first: Home, Your tunes.');
        final tune = pick.parsed!;
        final TuneDrill drill;
        try {
          drill = _tuneDrill = TuneDrill(
            tune,
            low: flute.low,
            high: flute.high,
            tuning: tuning,
            maxNotes: PhraseLevel.maxNotes(_level),
          );
        } on ArgumentError {
          throw StateError('No line of "${tune.title}" fits ${flute.name}.');
        }
        _nextDrill = drill.next;
        return (
          raga: null,
          rounds: null,
          keypad: {for (final l in tune.lines) ...l.pitches}.toList()..sort(_byPitch),
          title: tune.title,
          taal: null,
        );
      case PracticeMode.rhythm:
        final content = await ref.read(contentProvider.future);
        final lesson =
            content.rhythmLesson(settings.rhythmLessonId) ?? content.rhythmLessons.firstOrNull;
        if (lesson == null) throw StateError('No rhythm lessons are installed.');
        _nextDrill = RhythmDrill(lesson).next;
        return (
          raga: null,
          rounds: null,
          keypad: {for (final p in lesson.phrases) ...p.pitches}.toList()..sort(_byPitch),
          title: lesson.title,
          taal: lesson.taal,
        );
    }
  }

  /// Plays the call again, then listens.
  Future<void> replay() async {
    if (state == null) return;
    _stopTimers();
    if (!await _resume()) return;
    _call();
  }

  /// Listens again without replaying the call.
  Future<void> retry() async {
    if (state == null) return;
    _stopTimers();
    if (!await _resume()) return;
    if (state!.settings.naming) {
      _answers.clear();
      state = state!.copyWith(phase: PracticePhase.answering, answers: const []);
      return;
    }
    final settings = state!.settings;
    final matraSeconds = 60 / settings.tempo;
    final countIn = settings.clicks && settings.countIn ? countInLength(settings.taal) : 0;
    final round = state!.round!;
    // As long as after the call, sized from the phrase (D50).
    _listen(
      from: _audio.time + _frames100ms(1),
      phraseSeconds: round.target.length == 1
          ? _singleMatraSeconds
          : round.phrase.length.toDouble() * matraSeconds,
      leadSeconds: countIn * matraSeconds,
    );
    final clicks = _startClicks(
      origin: _audio.time + (0.3 * _audio.sampleRate).round(),
      matraSeconds: matraSeconds,
    );
    _recorder?.log('listen', {
      'round': state!.round!.number,
      'listenFrom': _listenFrom,
      'deadline': _deadline,
      'clicks': ?clicks,
    });
  }

  /// Plays madhya Sa as a reference, without changing the round.
  Future<void> hearSa() async {
    final s = state;
    if (s == null || !await _resume()) return;
    final sr = _audio.sampleRate;
    final call = scheduleCall(
      Phrase(
        notes: [Note(pitch: const Pitch(Swar.sa), start: Fraction.zero, duration: Fraction.one)],
      ),
      saHz: s.flute.saHz,
      start: _audio.time + (0.1 * sr).round(),
      sampleRate: sr,
      matraSeconds: 1.2,
      tuning: s.settings.tuning.tuning,
    );
    _audio.play(call.notes);
  }

  Future<void> next() async {
    _stopTimers();
    final s = state;
    if (s == null) return;
    if (s.rounds.length >= s.settings.rounds) {
      await finish();
    } else {
      if (!await _resume()) return;
      await _nextRound();
    }
  }

  /// Stops everything mid-session: the call, the clicks, the drone and the
  /// mic (the player tapped Pause, or the app went to the background).
  /// [resume] picks the session up again.
  void pause() {
    final s = state;
    if (s == null || !canPause(s.phase)) return;
    _stopTimers();
    _audio.stopPlayback();
    _audio.stopClicks();
    _audio.stop();
    _recorder?.pause();
    state = s.copyWith(phase: PracticePhase.paused);
  }

  /// Carries on after [pause]: plays the round's call again, or moves on if
  /// the round was already over.
  Future<void> resume() async {
    final s = state;
    if (s == null || s.phase != PracticePhase.paused) return;
    switch (resumeStep(s.round)) {
      case ResumeStep.nextRound:
        await next();
      case ResumeStep.replayCall:
        await replay();
    }
  }

  Future<void> finish() async {
    _stopTimers();
    ref.invalidate(phraseLevelProvider);
    _audio.stopPlayback();
    _audio.stopClicks();
    final id = _sessionId;
    if (id != null) {
      await (_db.update(
        _db.sessions,
      )..where((s) => s.id.equals(id))).write(SessionsCompanion(endedAt: Value(DateTime.now())));
    }
    if (_audio.loopbackMeasured) {
      await _db.setSetting(_loopbackKey, _audio.loopbackMs.toStringAsFixed(0));
    }
    _recorder?.log('finish');
    await _recorder?.stop();
    _recorder = null;
    _audio.setDrone(saHz: state!.flute.saHz, on: false);
    _audio.stop(); // the mic stays off outside practice
    state = state!.copyWith(phase: PracticePhase.finished);
  }

  Future<bool> _resume() async {
    if (_audio.running) return true;
    final ok = await _audio.ensureStarted(capture: !state!.settings.naming);
    if (!ok) {
      state = state!.copyWith(phase: PracticePhase.error, message: 'The microphone stopped.');
    } else {
      await _recorder?.resume();
    }
    return ok;
  }

  Future<void> _nextRound() async {
    final s = state!;
    final drill = _nextDrill();
    final round = RoundRecord(
      s.rounds.length + 1,
      drill.phrase,
      drill.label.isEmpty ? null : drill.label,
    );
    s.rounds.add(round);
    round.id = await _db
        .into(_db.rounds)
        .insert(
          RoundsCompanion.insert(
            sessionId: _sessionId!,
            number: round.number,
            target: printNotation(round.phrase),
          ),
        );
    _call();
  }

  /// Plays the target on the flute voice, then opens the listening window.
  void _call() {
    final s = state!;
    final phrase = s.round!.phrase;
    final single = s.round!.target.length == 1;
    final sr = _audio.sampleRate;
    final matraSeconds = single ? _singleMatraSeconds : 60 / s.settings.tempo;
    // With a count-in, the call waits for it (docs/08 M3-B).
    final origin = _audio.time + (0.3 * sr).round();
    final countIn = s.settings.clicks && s.settings.countIn ? countInLength(s.settings.taal) : 0;
    // A free start in a taal begins on the next sam after the call (D54).
    final toSam = s.settings.clicks && !s.settings.countIn && !single
        ? matrasToNextSam(_wholeMatras(phrase.length), s.settings.taal)
        : 0;
    final call = scheduleCall(
      phrase,
      saHz: s.flute.saHz,
      start: origin + (countIn * matraSeconds * sr).round(),
      sampleRate: sr,
      matraSeconds: matraSeconds,
      tuning: s.settings.tuning.tuning,
    );
    _audio.play(call.notes);
    final callSeconds = (call.end - call.notes.first.start) / sr;
    _callStart = call.notes.first.start;
    _callEnd = call.end;
    _callHz = call.notes.first.hz;
    _callMeasured = false;
    // The call reaches the mic one round trip late; listen once its echo has
    // passed (refined below when this call's own echo is measured).
    _listen(
      from: _listenAfterCall(),
      phraseSeconds: callSeconds,
      leadSeconds: (countIn + toSam) * matraSeconds,
    );
    final clicks = _startClicks(
      origin: origin,
      matraSeconds: matraSeconds,
      callMatras: _wholeMatras(phrase.length),
    );
    _recorder?.log('call', {
      'round': s.round!.number,
      'target': printNotation(phrase),
      'notes': [
        for (final n in call.notes) {'start': n.start, 'duration': n.duration, 'hz': n.hz},
      ],
      'listenFrom': _listenFrom,
      'deadline': _deadline,
      'loopbackMs': _audio.loopbackMs.round(),
      'clicks': ?clicks,
    });
    _answers.clear();
    state = s.copyWith(phase: PracticePhase.calling, answers: const []);
    if (s.settings.naming) {
      // No mic frames to clock the phases: switch when the call has played.
      final wait = Duration(microseconds: ((call.end - _audio.time) * 1e6 / sr).round());
      _phaseTimer = Timer(wait, () {
        if (state?.phase == PracticePhase.calling) {
          state = state!.copyWith(phase: PracticePhase.answering);
        }
      });
    }
  }

  /// A single swar is called and expected at this length.
  static const _singleMatraSeconds = 1.6;

  void _listen({required int from, required double phraseSeconds, double leadSeconds = 0}) {
    _heard.clear();
    _window = ListenWindow(
      from: from,
      phraseSeconds: phraseSeconds,
      leadSeconds: leadSeconds,
      sampleRate: _audio.sampleRate,
      minHz: hzFromCents(
        _segmenterConfig(state!, _audio.sampleRate).floorCents!,
        state!.flute.saHz,
      ),
    );
    if (state!.phase != PracticePhase.calling) {
      state = state!.copyWith(phase: PracticePhase.listening);
    }
  }

  int _frames100ms(int n) => (n * 0.1 * _audio.sampleRate).round();

  static int _wholeMatras(Fraction f) => f.isInteger ? f.numerator : f.floor() + 1;

  /// Schedules this round's metronome and count-in clicks (docs/08 M3-B) on
  /// the engine clock, the first at [origin], running to the end of the
  /// listening window. [callMatras] null: listening again, no call. Returns
  /// what to log, or null when the session doesn't click.
  Map<String, Object?>? _startClicks({
    required int origin,
    required double matraSeconds,
    int? callMatras,
  }) {
    final s = state!.settings;
    if (!s.clicks) return null;
    final sr = _audio.sampleRate;
    final matraFrames = matraSeconds * sr;
    RoundClicks plan(int responseMatras) => callMatras == null
        ? retryClicks(
            responseMatras: responseMatras,
            taal: s.taal,
            metronome: s.metronome,
            countIn: s.countIn,
          )
        : roundClicks(
            callMatras: callMatras,
            responseMatras: responseMatras,
            taal: s.taal,
            metronome: s.metronome,
            countIn: s.countIn,
          );
    final responseAt = origin + (plan(0).responseAt * matraFrames).round();
    // Clicks until the window could close at the latest (they stop when
    // the attempt is judged); the engine holds at most 256.
    final responseMatras = ((_window!.latestDeadline - responseAt) / matraFrames).ceil().clamp(
      0,
      200,
    );
    final p = plan(responseMatras);
    final clicks = scheduleClicks(
      p.clicks,
      start: origin,
      sampleRate: sr,
      matraSeconds: matraSeconds,
      volume: s.clickVolume,
    );
    _audio.playClicks(clicks);
    // Any sam of the player's turn can start the phrase (docs/05 §5).
    _sams = [for (final i in p.turnSams) clicks[i].time];
    _beats = BeatPlan([
      for (var i = 0; i < clicks.length; i++)
        (time: clicks[i].time, position: p.clicks[i].position),
    ], matraFrames.round());
    return {
      'taal': s.taalId,
      'metronome': s.metronome,
      'countIn': s.countIn,
      'first': origin,
      'callAt': origin + (p.callAt * matraFrames).round(),
      'responseAt': origin + (p.responseAt * matraFrames).round(),
      'count': clicks.length,
    };
  }

  int _listenAfterCall() =>
      _callEnd + _audio.loopbackFrames + (_afterEchoMs * _audio.sampleRate / 1000).round();

  /// The first tracker frame at the call's pitch gives this call's round trip.
  void _measureCallEcho(List<PitchFrame> batch) {
    for (final f in batch) {
      if (f.time < _callStart || f.hz <= 0 || f.confidence < 0.85) continue;
      if (centsFromSa(f.hz, _callHz).abs() > 30) continue;
      _callMeasured = true;
      _audio.reportLoopback(1000 * (f.time - _callStart) / _audio.sampleRate);
      final shift = _listenAfterCall() - _listenFrom;
      _window!.shift(shift);
      _recorder?.log('loopback', {
        'ms': _audio.loopbackMs.round(),
        'sample': (1000 * (f.time - _callStart) / _audio.sampleRate).round(),
        'listenFrom': _listenFrom,
      });
      return;
    }
  }

  void _onFrames(List<PitchFrame> batch) {
    final s = state;
    if (s == null) return;
    final last = batch.last;
    final level = last.rms <= 0
        ? 0.0
        : ((20 * math.log(last.rms) / math.ln10 + 60) / 50).clamp(0.0, 1.0);

    if (s.phase == PracticePhase.calling) {
      if (!_callMeasured) _measureCallEcho(batch);
      if (last.time >= _listenFrom) {
        state = s.copyWith(phase: PracticePhase.listening, level: level);
      }
      return;
    }
    if (s.phase != PracticePhase.listening) return;

    _heard.addAll(batch.where((f) => f.time >= _listenFrom));
    _window?.heard(batch);
    state = s.copyWith(level: level);
    if (_finishedPlaying(last.time)) _judge();
  }

  /// End-of-attempt rules: the player has played enough and gone quiet, or a
  /// single note has clearly been held, or time ran out.
  bool _finishedPlaying(int now) {
    if (now >= _deadline) return true;
    final sr = _audio.sampleRate;
    final voiced = _heard.lastWhere((f) => f.hz > 0 && f.confidence >= 0.85, orElse: () => _none);
    if (identical(voiced, _none)) return false;
    final quietMs = 1000 * (now - voiced.time) / sr;
    final notes = segmentNotes(
      _heard,
      saHz: state!.flute.saHz,
      tuning: state!.settings.tuning.tuning,
      config: _segmenterConfig(state!, sr),
    );
    final target = state!.round!.target;
    if (target.length == 1) {
      final held = notes.where((n) => n.durationMs(sr) >= 300);
      if (held.isEmpty) return false;
      return quietMs >= 500 || held.first.durationMs(sr) >= 1500;
    }
    if (notes.length >= target.length && quietMs >= 600) return true;
    return notes.isNotEmpty && quietMs >= 1500;
  }

  static const _none = PitchFrame(time: -1, hz: 0, confidence: 0, rms: 0);

  /// Notes more than a semitone below the flute's lowest note can't have
  /// been played: they are the drone, read at the tracker's floor (D37).
  static SegmenterConfig _segmenterConfig(PracticeState s, int sampleRate) => SegmenterConfig(
    sampleRate: sampleRate,
    floorCents: s.settings.tuning.tuning.centsOf(s.flute.low) - 100,
  );

  Future<void> _judge() async {
    _audio.stopClicks();
    final s = state!;
    final round = s.round!;
    final sr = _audio.sampleRate;
    final notes = segmentNotes(
      _heard,
      saHz: s.flute.saHz,
      tuning: s.settings.tuning.tuning,
      config: _segmenterConfig(s, sr),
    );
    final judge = s.settings.judge(sr);
    var result = round.target.length == 1
        ? judgeSingle(round.target.single, notes, judge)
        : judgePhrase(round.target, notes, judge);
    final matraFrames = 60 / s.settings.tempo * sr;
    // The stored measurement, else the call's echo (they agree, D45).
    final delayFrames = ((_timingDelayMs ?? _audio.loopbackMs) * sr / 1000).round();
    if (_timing) {
      result = result.withRhythm(
        judgeRhythm(
          round.phrase,
          result,
          sams: _sams,
          matraFrames: matraFrames,
          delayFrames: delayFrames,
        ),
        strict: s.settings.strictRhythm,
      );
    }
    round.traces.add(
      buildPitchTrace(
        _heard,
        result,
        round.target,
        saHz: s.flute.saHz,
        tuning: s.settings.tuning.tuning,
        config: _segmenterConfig(s, sr),
      ),
    );
    round.attempts.add(result);
    state = s.copyWith(phase: PracticePhase.verdict, level: 0);
    _recorder?.log('judge', {
      'round': round.number,
      'attempt': round.attempts.length,
      'target': printNotation(round.phrase),
      'listenFrom': _listenFrom,
      'lastFrame': _heard.isEmpty ? null : _heard.last.time,
      // Where the window closed by then, and where the player started (D50).
      'deadline': _deadline,
      'started': ?_window?.started,
      'passed': result.passed,
      'result': attemptToJson(result),
      if (_timing)
        'rhythm': {
          'sams': _sams,
          'matraFrames': matraFrames,
          'delayFrames': delayFrames,
          'measuredDelay': _timingDelayMs != null,
          'sam': ?result.rhythm?.sam,
          'drift': ?result.rhythm?.drift?.name,
          'tempoRatio': ?result.rhythm?.tempoRatio,
        },
      'detected': [
        for (final n in notes)
          {
            'pitch': n.pitch.ascii,
            'onset': n.onset,
            'end': n.end,
            'deviation': double.parse(n.deviation.toStringAsFixed(1)),
            'crack': ?n.crack?.ascii,
          },
      ],
    });

    await _conclude(result);
  }

  /// Listen & name: one tapped swar. Each tap is checked as it comes; once
  /// the target's length is reached the attempt is judged. A tap after a
  /// miss starts the next attempt.
  Future<void> answer(Pitch pitch) async {
    final s = state;
    final round = s?.round;
    if (s == null || round == null || round.passed || round.gaveUp) return;
    const open = {PracticePhase.calling, PracticePhase.answering, PracticePhase.verdict};
    if (!open.contains(s.phase)) return;
    _stopTimers();
    if (s.phase == PracticePhase.verdict) _answers.clear();
    _answers.add(pitch);
    if (_answers.length < round.target.length) {
      state = s.copyWith(phase: PracticePhase.answering, answers: List.of(_answers));
      return;
    }
    final result = judgeNamed(round.target, _answers, s.settings.judge(_audio.sampleRate));
    round.attempts.add(result);
    state = s.copyWith(phase: PracticePhase.verdict, answers: List.of(_answers));
    await _conclude(result);
  }

  /// Stores a judged attempt and decides what comes next (docs/08 M2-A).
  /// A phrase round's first try moves the phrase level, when it grows.
  Future<void> _countForLevel(bool passed) async {
    final tracker = _levelTracker;
    final s = state;
    if (tracker == null || s == null) return;
    final change = tracker.add(passed);
    await savePhraseLevel(_db, tracker, naming: s.settings.naming);
    if (change == 0) return;
    _level = tracker.level;
    _ragaDrill?.maxNotes = PhraseLevel.maxNotes(_level);
    _tuneDrill?.maxNotes = PhraseLevel.maxNotes(_level);
    _recorder?.log('phraseLevel', {'level': _level, 'change': change});
    state = PracticeState(
      phase: s.phase,
      flute: s.flute,
      settings: s.settings,
      rounds: s.rounds,
      level: s.level,
      answers: s.answers,
      keypad: s.keypad,
      title: s.title,
      phraseLevel: _level,
    );
  }

  Future<void> _conclude(AttemptResult result) async {
    final s = state!;
    final round = s.round!;
    // First tries also teach this session's drilling as it goes.
    if (round.attempts.length == 1) {
      for (final note in attemptToJson(result)) {
        final o = outcomeFromJson(
          note,
          tuning: s.settings.tuning.tuning,
          at: DateTime.now(),
          fluteId: s.flute.id,
          named: s.settings.naming,
        );
        if (o != null) _history?.add(o);
      }
      if (round.target.length > 1) await _countForLevel(result.passed);
    }
    await _db
        .into(_db.attempts)
        .insert(
          AttemptsCompanion.insert(
            roundId: round.id!,
            number: round.attempts.length,
            passed: result.passed,
            resultJson: jsonEncode(attemptToJson(result)),
            createdAt: DateTime.now(),
          ),
        );

    if (result.passed) {
      // Naming is quick, so its rounds move on sooner.
      final pause = Duration(milliseconds: s.settings.naming ? 1000 : 1500);
      if (s.settings.autoAdvance) _advance = Timer(pause, next);
      return;
    }
    switch (afterMiss(round.misses, s.settings)) {
      case MissStep.giveUp:
        round.gaveUp = true;
        _recorder?.log('giveUp', {'round': round.number, 'misses': round.misses});
        state = state!.copyWith();
        // A little longer than after a pass, to take in the answer.
        if (s.settings.autoAdvance) _advance = Timer(const Duration(seconds: 4), next);
      case MissStep.autoRetry:
        // Naming needs no hands-free countdown: a tap starts the next try.
        // It can still replay the call first.
        if (!s.settings.naming) {
          _startCountdown();
        } else if (s.settings.replayBeforeRetry) {
          _advance = Timer(const Duration(milliseconds: 1200), replay);
        }
      case MissStep.wait:
        break;
    }
  }

  /// "Listening again in 3… 2… 1…", then retry (or replay, per settings).
  void _startCountdown() {
    var left = 3;
    state = state!.copyWith(countdown: left);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      left--;
      if (left > 0) {
        state = state!.copyWith(countdown: left);
        return;
      }
      timer.cancel();
      _countdown = null;
      final settings = state!.settings;
      _recorder?.log('autoRetry', {
        'round': state!.round!.number,
        'replay': settings.replayBeforeRetry,
      });
      settings.replayBeforeRetry ? replay() : retry();
    });
  }

  /// A tap during the countdown: stop and wait for the player.
  void holdCountdown() {
    if (_countdown == null) return;
    _countdown!.cancel();
    _countdown = null;
    state = state!.copyWith();
  }

  void _stopTimers() {
    _advance?.cancel();
    _countdown?.cancel();
    _countdown = null;
    _phaseTimer?.cancel();
  }

  void _cleanUp() {
    _frames?.cancel();
    _frames = null;
    _stopTimers();
    _recorder?.stop();
    _recorder = null;
  }
}

/// Stored per attempt (Attempts.resultJson).
List<Map<String, Object?>> attemptToJson(AttemptResult r) {
  var k = 0;
  return [
    for (final n in r.notes)
      () {
        // Rhythm practice: each target's timing, in matras from its place.
        final timing = n.target == null ? null : r.rhythm?.notes[k++];
        return {
          'target': n.target?.ascii,
          'verdict': n.verdict.name,
          'played': n.played?.pitch.ascii,
          'deviation': n.deviation == null ? null : double.parse(n.deviation!.toStringAsFixed(1)),
          // The swar a cracked attack touched first (D48); absent when clean.
          'crack': ?n.played?.crack?.ascii,
          if (timing != null) 'offset': double.parse(timing.offset.toStringAsFixed(2)),
          if (timing?.held != null) 'held': double.parse(timing!.held!.toStringAsFixed(2)),
        };
      }(),
  ];
}
