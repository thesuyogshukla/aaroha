import 'dart:math' as math;

/// Western pitch classes, used to name a flute's key.
enum PitchClass {
  c('C'),
  cSharp('C#'),
  d('D'),
  dSharp('D#'),
  e('E'),
  f('F'),
  fSharp('F#'),
  g('G'),
  gSharp('G#'),
  a('A'),
  aSharp('A#'),
  b('B');

  const PitchClass(this.label);
  final String label;
}

enum FluteSize { bass, medium }

/// A flute's nominal key, before calibration. The octave convention is an
/// assumption (docs/02-music-model.md): medium flutes in G–B have Sa in the
/// 4th octave, C–F# in the 5th; bass flutes sit one octave lower.
/// Calibration measures the real Sa, so this is only used for defaults and
/// sanity checks.
class FluteKey {
  const FluteKey(this.pitchClass, this.size);

  final PitchClass pitchClass;
  final FluteSize size;

  int get saOctave {
    final medium = pitchClass.index >= PitchClass.g.index ? 4 : 5;
    return size == FluteSize.medium ? medium : medium - 1;
  }

  /// Equal-tempered Sa at A4 = 440 Hz.
  double get nominalSaHz {
    final midi = 12 * (saOctave + 1) + pitchClass.index;
    return 440.0 * math.pow(2, (midi - 69) / 12);
  }

  String get name => '${pitchClass.label} ${size == FluteSize.medium ? 'medium' : 'bass'}';

  @override
  String toString() => name;
}

/// The owner's flutes (CLAUDE.md), used as presets until flute profiles land.
const ownerFlutes = [
  FluteKey(PitchClass.g, FluteSize.medium),
  FluteKey(PitchClass.a, FluteSize.medium),
  FluteKey(PitchClass.aSharp, FluteSize.medium),
  FluteKey(PitchClass.b, FluteSize.medium),
  FluteKey(PitchClass.c, FluteSize.medium),
  FluteKey(PitchClass.cSharp, FluteSize.medium),
  FluteKey(PitchClass.d, FluteSize.medium),
  FluteKey(PitchClass.dSharp, FluteSize.medium),
];
