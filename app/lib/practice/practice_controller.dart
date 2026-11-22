import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_audio/aaroha_audio.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../audio/audio_service.dart';
import '../data/database.dart';
import '../data/providers.dart';
import 'practice_settings.dart';
import 'session_recorder.dart';

/// The round loop from docs/04-architecture.md:
/// calling → listening → verdict → (retry | replay | next) … → finished.
/// `answering`: Listen & name, waiting for taps (instead of `listening`).
enum PracticePhase { starting, calling, listening, answering, verdict, paused, finished, error }

class RoundRecord {
  RoundRecord(this.number, this.target);
  final int number;
  final List<Pitch> target;
  final attempts = <AttemptResult>[];
  int? id;

  /// The player hit the give-up limit and the answer was revealed (M2-A).
  bool gaveUp = false;

  int get misses => attempts.where((a) => !a.passed).length;

  bool get firstTryPassed => attempts.isNotEmpty && attempts.first.passed;
  bool get passed => attempts.any((a) => a.passed);
}

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
  );
}

final practiceProvider = NotifierProvider<PracticeController, PracticeState?>(
  PracticeController.new,
);

class PracticeController extends Notifier<PracticeState?> {
  StreamSubscription<List<PitchFrame>>? _frames;
  Timer? _advance;
  Timer? _countdown;
  Timer? _phaseTimer;
  final _answers = <Pitch>[];
  late TargetGenerator _targets;
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
  int _listenFrom = 0;
  int _deadline = 0;
  final _heard = <PitchFrame>[];

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
    _targets = TargetGenerator(
      practicePitches(settings.swarSet, settings.range, low: flute.low, high: flute.high),
    );
    _audio.configureFor(flute.saHz);
    _audio.setDrone(saHz: flute.saHz, volume: settings.droneVolume, on: settings.droneOn);
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
    _listen(from: _audio.time + _frames100ms(1), seconds: 8);
    _recorder?.log('listen', {
      'round': state!.round!.number,
      'listenFrom': _listenFrom,
      'deadline': _deadline,
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

  /// Stops listening (e.g. the app went to the background).
  void pause() {
    final s = state;
    if (s == null || s.phase == PracticePhase.finished) return;
    _stopTimers();
    _audio.stopPlayback();
    _audio.stop();
    _recorder?.pause();
    state = s.copyWith(phase: PracticePhase.paused);
  }

  Future<void> finish() async {
    _stopTimers();
    _audio.stopPlayback();
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
    final target = s.settings.mode == PracticeMode.single ? _targets.single() : _targets.phrase();
    final round = RoundRecord(s.rounds.length + 1, target);
    s.rounds.add(round);
    round.id = await _db
        .into(_db.rounds)
        .insert(
          RoundsCompanion.insert(
            sessionId: _sessionId!,
            number: round.number,
            target: target.map((p) => p.ascii).join(' '),
          ),
        );
    _call();
  }

  /// Plays the target on the flute voice, then opens the listening window.
  void _call() {
    final s = state!;
    final target = s.round!.target;
    final single = target.length == 1;
    final phrase = Phrase(
      notes: [
        for (var i = 0; i < target.length; i++)
          Note(pitch: target[i], start: Fraction(i), duration: Fraction.one),
      ],
    );
    final sr = _audio.sampleRate;
    final call = scheduleCall(
      phrase,
      saHz: s.flute.saHz,
      start: _audio.time + (0.3 * sr).round(),
      sampleRate: sr,
      matraSeconds: single ? 1.6 : 0.8,
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
    _listen(from: _listenAfterCall(), seconds: callSeconds * 2 + 4);
    _recorder?.log('call', {
      'round': s.round!.number,
      'target': target.map((p) => p.ascii).join(' '),
      'notes': [
        for (final n in call.notes) {'start': n.start, 'duration': n.duration, 'hz': n.hz},
      ],
      'listenFrom': _listenFrom,
      'deadline': _deadline,
      'loopbackMs': _audio.loopbackMs.round(),
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

  void _listen({required int from, required double seconds}) {
    _heard.clear();
    _listenFrom = from;
    _deadline = from + (seconds * _audio.sampleRate).round();
    if (state!.phase != PracticePhase.calling) {
      state = state!.copyWith(phase: PracticePhase.listening);
    }
  }

  int _frames100ms(int n) => (n * 0.1 * _audio.sampleRate).round();

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
      _listenFrom += shift;
      _deadline += shift;
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
      config: SegmenterConfig(sampleRate: sr),
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

  Future<void> _judge() async {
    final s = state!;
    final round = s.round!;
    final sr = _audio.sampleRate;
    final notes = segmentNotes(
      _heard,
      saHz: s.flute.saHz,
      tuning: s.settings.tuning.tuning,
      config: SegmenterConfig(sampleRate: sr),
    );
    final judge = s.settings.judge(sr);
    final result = round.target.length == 1
        ? judgeSingle(round.target.single, notes, judge)
        : judgePhrase(round.target, notes, judge);
    round.attempts.add(result);
    state = s.copyWith(phase: PracticePhase.verdict, level: 0);
    _recorder?.log('judge', {
      'round': round.number,
      'attempt': round.attempts.length,
      'target': round.target.map((p) => p.ascii).join(' '),
      'listenFrom': _listenFrom,
      'lastFrame': _heard.isEmpty ? null : _heard.last.time,
      'passed': result.passed,
      'result': attemptToJson(result),
      'detected': [
        for (final n in notes)
          {
            'pitch': n.pitch.ascii,
            'onset': n.onset,
            'end': n.end,
            'deviation': double.parse(n.deviation.toStringAsFixed(1)),
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
  Future<void> _conclude(AttemptResult result) async {
    final s = state!;
    final round = s.round!;
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
List<Map<String, Object?>> attemptToJson(AttemptResult r) => [
  for (final n in r.notes)
    {
      'target': n.target?.ascii,
      'verdict': n.verdict.name,
      'played': n.played?.pitch.ascii,
      'deviation': n.deviation == null ? null : double.parse(n.deviation!.toStringAsFixed(1)),
    },
];
