import 'dart:convert';

import 'package:aaroha_core/aaroha_core.dart';

enum PracticeMode {
  single('Single swar'),
  phrase('Short phrase'),
  alankar('Alankar'),
  raga('Raga'),
  rhythm('Rhythm'),
  tune('Your tunes');

  const PracticeMode(this.label);
  final String label;
}

/// How the player answers: play it back on the flute, or name it by tapping
/// swar buttons (Listen & name, docs/08 M2-B; no mic).
enum AnswerBy {
  play('Play it'),
  name('Name it');

  const AnswerBy(this.label);
  final String label;
}

/// When the target's notation is shown (docs/08 M2-A). With "After a miss,
/// show: the answer", a miss also reveals it.
enum ShowTarget {
  always('Always'),
  roundEnd('When the round ends'),
  never('Never');

  const ShowTarget(this.label);
  final String label;
}

/// What happens after a missed attempt (M2-A).
enum MissAction {
  wait('Wait for me'),
  autoRetry('Try again automatically');

  const MissAction(this.label);
  final String label;
}

/// What a missed attempt reveals (M2-A).
enum MissReveal {
  answer('The answer'),
  hint('A hint'),
  nothing('Nothing');

  const MissReveal(this.label);
  final String label;
}

enum Script {
  latin('S R G'),
  devanagari('सा रे ग');

  const Script(this.label);
  final String label;
}

/// Reference tuning for the call and for judging (docs/02-music-model.md).
enum TuningChoice {
  just('Just', Tuning.just),
  equal('Equal', Tuning.equal);

  const TuningChoice(this.label, this.tuning);
  final String label;
  final Tuning tuning;
}

/// Practice settings (docs/01-product.md).
class PracticeSettings {
  const PracticeSettings({
    this.mode = PracticeMode.single,
    this.answerBy = AnswerBy.play,
    this.swarSet = SwarSet.shuddha,
    this.range = SaptakRange.madhya,
    this.showTarget = ShowTarget.roundEnd,
    this.script = Script.latin,
    this.toleranceCents = 25,
    this.octaveMustMatch = true,
    this.rounds = 20,
    this.droneOn = true,
    this.droneVolume = 0.5,
    this.autoAdvance = true,
    this.saveSessionAudio = true,
    this.tuning = TuningChoice.just,
    this.strictIntonation = false,
    this.missAction = MissAction.wait,
    this.replayBeforeRetry = true,
    this.giveUpAfter = 3,
    this.missReveal = MissReveal.answer,
    this.adaptive = true,
    this.alankarId = 'alankar-1',
    this.alankarScale = 'shuddha',
    this.ragaId = 'bhupali',
    this.phraseLevel = 0,
    this.showTrace = true,
    this.tempo = 75,
    this.metronome = false,
    this.countIn = false,
    this.taalId = 'none',
    this.clickVolume = 0.6,
    this.rhythmLessonId = 'keherwa-1',
    this.strictRhythm = false,
    this.tuneId,
  });

  final PracticeMode mode;
  final AnswerBy answerBy;

  /// Rhythm practice is always played.
  bool get naming => answerBy == AnswerBy.name && mode != PracticeMode.rhythm;
  final SwarSet swarSet;
  final SaptakRange range;
  final ShowTarget showTarget;
  final Script script;
  final double toleranceCents;
  final bool octaveMustMatch;
  final int rounds;
  final bool droneOn;
  final double droneVolume;
  final bool autoAdvance;

  /// Save each session's mic audio and an event log, for tuning the app.
  final bool saveSessionAudio;

  /// Just intonation by default: it fits how the owner plays Dha and Ni and
  /// matches the tanpura (decisions.md D31).
  final TuningChoice tuning;

  /// Off: the right swar passes even when out of tune (ear first, D31).
  final bool strictIntonation;

  final MissAction missAction;

  /// With automatic retries: play the call again before listening.
  final bool replayBeforeRetry;

  /// Misses before the answer is revealed and the round ends; 0 = never.
  final int giveUpAfter;
  final MissReveal missReveal;

  /// Smart drilling: pick swars you miss more often, and contrast drills
  /// for pairs you confuse (docs/05 §8).
  final bool adaptive;

  /// Alankar mode: which pattern, on which scale: a [SwarSet] name or a raga
  /// id (the raga's aaroh going up, its avaroh coming down).
  final String alankarId;
  final String alankarScale;

  /// Raga mode: which raga's phrases.
  final String ragaId;

  /// How long phrases may be (docs/05 §9): 0 grows with the player's first
  /// tries; 1–5 holds a level (2–4 notes up to 6–8).
  final int phraseLevel;

  bool get phraseLevelGrows => phraseLevel == 0;

  /// After each played try, draw the pitch curve against the target
  /// (docs/05 §10). Never live.
  final bool showTrace;

  /// Matras per minute for the call of a phrase (docs/08 M3-A). A single swar
  /// keeps its own longer note. 75 is the 0.8 s per note phrases had before.
  final int tempo;

  /// The tempos offered on Home, slow to brisk.
  static const tempos = [50, 60, 75, 90, 110];

  /// A click on every matra of the call and of the player's turn (docs/08
  /// M3-B). Played phrases only.
  final bool metronome;

  /// A count-in before the call and before the player's turn; off is a free
  /// start, where the player begins when ready.
  final bool countIn;

  /// The taal the clicks follow, by id; 'none' is a plain beat.
  final String taalId;
  final double clickVolume;

  /// Rhythm mode: which lesson (docs/08 M3-E).
  final String rhythmLessonId;

  /// Rhythm mode: off, timing is reported and doesn't fail the round
  /// (decisions.md D42); on, every note must be on time too.
  final bool strictRhythm;

  /// Your tunes: which tune, by its database id (D56); null before one is
  /// picked.
  final int? tuneId;

  Taal? get taal => taalId == 'none' ? null : Taal.byId(taalId);

  /// The taals offered on Home (docs/08 M3).
  static const taals = [Taal.keherwa, Taal.dadra, Taal.teentaal, Taal.rupak];

  /// Whether this session clicks at all: played phrases, with the metronome
  /// or a count-in on. A single swar and naming never click.
  bool get clicks =>
      mode == PracticeMode.rhythm ||
      (!naming && mode != PracticeMode.single && (metronome || countIn));

  /// The raga whose drone and scale this session uses, if any.
  String? get ragaInUse => switch (mode) {
    PracticeMode.raga => ragaId,
    PracticeMode.alankar when !SwarSet.values.any((s) => s.name == alankarScale) => alankarScale,
    _ => null,
  };

  JudgeSettings judge(int sampleRate) => JudgeSettings(
    toleranceCents: toleranceCents,
    octaveMustMatch: octaveMustMatch,
    tuning: tuning.tuning,
    sampleRate: sampleRate,
    strictIntonation: strictIntonation,
  );

  PracticeSettings copyWith({
    PracticeMode? mode,
    AnswerBy? answerBy,
    SwarSet? swarSet,
    SaptakRange? range,
    ShowTarget? showTarget,
    Script? script,
    double? toleranceCents,
    bool? octaveMustMatch,
    int? rounds,
    bool? droneOn,
    double? droneVolume,
    bool? autoAdvance,
    bool? saveSessionAudio,
    TuningChoice? tuning,
    bool? strictIntonation,
    MissAction? missAction,
    bool? replayBeforeRetry,
    int? giveUpAfter,
    MissReveal? missReveal,
    bool? adaptive,
    String? alankarId,
    String? alankarScale,
    String? ragaId,
    int? phraseLevel,
    bool? showTrace,
    int? tempo,
    bool? metronome,
    bool? countIn,
    String? taalId,
    double? clickVolume,
    String? rhythmLessonId,
    bool? strictRhythm,
    int? tuneId,
  }) => PracticeSettings(
    mode: mode ?? this.mode,
    answerBy: answerBy ?? this.answerBy,
    swarSet: swarSet ?? this.swarSet,
    range: range ?? this.range,
    showTarget: showTarget ?? this.showTarget,
    script: script ?? this.script,
    toleranceCents: toleranceCents ?? this.toleranceCents,
    octaveMustMatch: octaveMustMatch ?? this.octaveMustMatch,
    rounds: rounds ?? this.rounds,
    droneOn: droneOn ?? this.droneOn,
    droneVolume: droneVolume ?? this.droneVolume,
    autoAdvance: autoAdvance ?? this.autoAdvance,
    saveSessionAudio: saveSessionAudio ?? this.saveSessionAudio,
    tuning: tuning ?? this.tuning,
    strictIntonation: strictIntonation ?? this.strictIntonation,
    missAction: missAction ?? this.missAction,
    replayBeforeRetry: replayBeforeRetry ?? this.replayBeforeRetry,
    giveUpAfter: giveUpAfter ?? this.giveUpAfter,
    missReveal: missReveal ?? this.missReveal,
    adaptive: adaptive ?? this.adaptive,
    alankarId: alankarId ?? this.alankarId,
    alankarScale: alankarScale ?? this.alankarScale,
    ragaId: ragaId ?? this.ragaId,
    phraseLevel: phraseLevel ?? this.phraseLevel,
    showTrace: showTrace ?? this.showTrace,
    tempo: tempo ?? this.tempo,
    metronome: metronome ?? this.metronome,
    countIn: countIn ?? this.countIn,
    taalId: taalId ?? this.taalId,
    clickVolume: clickVolume ?? this.clickVolume,
    rhythmLessonId: rhythmLessonId ?? this.rhythmLessonId,
    strictRhythm: strictRhythm ?? this.strictRhythm,
    tuneId: tuneId ?? this.tuneId,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'answerBy': answerBy.name,
    'swarSet': swarSet.name,
    'range': range.name,
    'showTarget': showTarget.name,
    'script': script.name,
    'toleranceCents': toleranceCents,
    'octaveMustMatch': octaveMustMatch,
    'rounds': rounds,
    'droneOn': droneOn,
    'droneVolume': droneVolume,
    'autoAdvance': autoAdvance,
    'saveSessionAudio': saveSessionAudio,
    'tuning': tuning.name,
    'strictIntonation': strictIntonation,
    'missAction': missAction.name,
    'replayBeforeRetry': replayBeforeRetry,
    'giveUpAfter': giveUpAfter,
    'missReveal': missReveal.name,
    'adaptive': adaptive,
    'alankarId': alankarId,
    'alankarScale': alankarScale,
    'ragaId': ragaId,
    'phraseLevel': phraseLevel,
    'showTrace': showTrace,
    'tempo': tempo,
    'metronome': metronome,
    'countIn': countIn,
    'taal': taalId,
    'clickVolume': clickVolume,
    'rhythmLesson': rhythmLessonId,
    'strictRhythm': strictRhythm,
    'tuneId': ?tuneId,
  };

  factory PracticeSettings.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    const d = PracticeSettings();
    return PracticeSettings(
      mode: byName(PracticeMode.values, j['mode'], d.mode),
      answerBy: byName(AnswerBy.values, j['answerBy'], d.answerBy),
      swarSet: byName(SwarSet.values, j['swarSet'], d.swarSet),
      range: byName(SaptakRange.values, j['range'], d.range),
      // Before M2-A this was "notation": shown / afterAttempt / hidden.
      showTarget: j['showTarget'] != null
          ? byName(ShowTarget.values, j['showTarget'], d.showTarget)
          : switch (j['notation']) {
              'shown' => ShowTarget.always,
              'hidden' => ShowTarget.never,
              _ => d.showTarget,
            },
      script: byName(Script.values, j['script'], d.script),
      toleranceCents: (j['toleranceCents'] as num?)?.toDouble() ?? d.toleranceCents,
      octaveMustMatch: j['octaveMustMatch'] as bool? ?? d.octaveMustMatch,
      rounds: j['rounds'] as int? ?? d.rounds,
      droneOn: j['droneOn'] as bool? ?? d.droneOn,
      droneVolume: (j['droneVolume'] as num?)?.toDouble() ?? d.droneVolume,
      autoAdvance: j['autoAdvance'] as bool? ?? d.autoAdvance,
      saveSessionAudio: j['saveSessionAudio'] as bool? ?? d.saveSessionAudio,
      tuning: byName(TuningChoice.values, j['tuning'], d.tuning),
      strictIntonation: j['strictIntonation'] as bool? ?? d.strictIntonation,
      missAction: byName(MissAction.values, j['missAction'], d.missAction),
      replayBeforeRetry: j['replayBeforeRetry'] as bool? ?? d.replayBeforeRetry,
      giveUpAfter: j['giveUpAfter'] as int? ?? d.giveUpAfter,
      missReveal: byName(MissReveal.values, j['missReveal'], d.missReveal),
      adaptive: j['adaptive'] as bool? ?? d.adaptive,
      alankarId: j['alankarId'] as String? ?? d.alankarId,
      alankarScale: j['alankarScale'] as String? ?? d.alankarScale,
      ragaId: j['ragaId'] as String? ?? d.ragaId,
      phraseLevel: ((j['phraseLevel'] as int?) ?? d.phraseLevel).clamp(0, PhraseLevel.top),
      showTrace: j['showTrace'] as bool? ?? d.showTrace,
      tempo: ((j['tempo'] as int?) ?? d.tempo).clamp(30, 200),
      metronome: j['metronome'] as bool? ?? d.metronome,
      countIn: j['countIn'] as bool? ?? d.countIn,
      taalId: Taal.byId('${j['taal']}') != null ? '${j['taal']}' : d.taalId,
      clickVolume: ((j['clickVolume'] as num?)?.toDouble() ?? d.clickVolume).clamp(0.0, 1.0),
      rhythmLessonId: j['rhythmLesson'] as String? ?? d.rhythmLessonId,
      strictRhythm: j['strictRhythm'] as bool? ?? d.strictRhythm,
      tuneId: j['tuneId'] as int?,
    );
  }
}

/// What the round loop does after a missed attempt (docs/08 M2-A).
enum MissStep { wait, autoRetry, giveUp }

/// [misses] counts this round's failed attempts, including the one just judged.
MissStep afterMiss(int misses, PracticeSettings settings) {
  if (settings.giveUpAfter > 0 && misses >= settings.giveUpAfter) return MissStep.giveUp;
  return settings.missAction == MissAction.autoRetry ? MissStep.autoRetry : MissStep.wait;
}

/// A session's one-line description for History, from its stored settings.
String sessionLabel(String settingsJson) {
  final Map<String, dynamic> j;
  try {
    j = jsonDecode(settingsJson) as Map<String, dynamic>;
  } on FormatException {
    return 'practice';
  }
  final s = PracticeSettings.fromJson(j);
  String title(String id) => id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);
  final what = switch (s.mode) {
    PracticeMode.single => 'single swar',
    PracticeMode.phrase => 'phrases',
    PracticeMode.alankar => s.ragaInUse == null ? 'alankar' : 'alankar in ${title(s.ragaInUse!)}',
    PracticeMode.raga => 'raga ${title(s.ragaId)}',
    PracticeMode.rhythm => 'rhythm, ${s.rhythmLessonId.replaceAll('-', ' ')}',
    PracticeMode.tune => 'your tune',
  };
  return s.naming ? '$what · named' : what;
}
