import 'package:aaroha_core/aaroha_core.dart';

enum PracticeMode {
  single('Single swar'),
  phrase('Short phrase');

  const PracticeMode(this.label);
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
  });

  final PracticeMode mode;
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

  JudgeSettings judge(int sampleRate) => JudgeSettings(
    toleranceCents: toleranceCents,
    octaveMustMatch: octaveMustMatch,
    tuning: tuning.tuning,
    sampleRate: sampleRate,
    strictIntonation: strictIntonation,
  );

  PracticeSettings copyWith({
    PracticeMode? mode,
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
  }) => PracticeSettings(
    mode: mode ?? this.mode,
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
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
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
  };

  factory PracticeSettings.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    const d = PracticeSettings();
    return PracticeSettings(
      mode: byName(PracticeMode.values, j['mode'], d.mode),
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
