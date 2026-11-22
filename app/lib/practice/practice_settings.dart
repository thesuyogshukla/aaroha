import 'package:aaroha_core/aaroha_core.dart';

enum PracticeMode {
  single('Single swar'),
  phrase('Short phrase');

  const PracticeMode(this.label);
  final String label;
}

/// When the target's notation is shown (docs/01-product.md).
enum NotationDisplay {
  shown('Shown'),
  afterAttempt('After attempt'),
  hidden('Hidden');

  const NotationDisplay(this.label);
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

/// Settings from docs/01-product.md that v0.1 uses.
class PracticeSettings {
  const PracticeSettings({
    this.mode = PracticeMode.single,
    this.swarSet = SwarSet.shuddha,
    this.range = SaptakRange.madhya,
    this.notation = NotationDisplay.afterAttempt,
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
  });

  final PracticeMode mode;
  final SwarSet swarSet;
  final SaptakRange range;
  final NotationDisplay notation;
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
    NotationDisplay? notation,
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
  }) => PracticeSettings(
    mode: mode ?? this.mode,
    swarSet: swarSet ?? this.swarSet,
    range: range ?? this.range,
    notation: notation ?? this.notation,
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
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'swarSet': swarSet.name,
    'range': range.name,
    'notation': notation.name,
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
  };

  factory PracticeSettings.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    const d = PracticeSettings();
    return PracticeSettings(
      mode: byName(PracticeMode.values, j['mode'], d.mode),
      swarSet: byName(SwarSet.values, j['swarSet'], d.swarSet),
      range: byName(SaptakRange.values, j['range'], d.range),
      notation: byName(NotationDisplay.values, j['notation'], d.notation),
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
    );
  }
}
