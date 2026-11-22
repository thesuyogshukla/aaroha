/// The twelve swars of an octave, in ascending order. See docs/02-music-model.md.
enum Swar {
  sa('S', 'Sa', 'सा'),
  komalRe('r', 'komal Re', 'रे'),
  re('R', 'Re', 'रे'),
  komalGa('g', 'komal Ga', 'ग'),
  ga('G', 'Ga', 'ग'),
  ma('m', 'Ma', 'म'),
  tivraMa('M', 'tivra Ma', 'म॑'),
  pa('P', 'Pa', 'प'),
  komalDha('d', 'komal Dha', 'ध'),
  dha('D', 'Dha', 'ध'),
  komalNi('n', 'komal Ni', 'नि'),
  ni('N', 'Ni', 'नि');

  const Swar(this.ascii, this.label, this.devanagari);

  /// Letter used in the notation (docs/03-notation.md).
  final String ascii;

  /// Human-readable name, e.g. "komal Ga".
  final String label;

  /// Devanagari syllable. Komal and tivra marks are applied when rendering.
  final String devanagari;

  /// Semitones above Sa.
  int get semitone => index;

  bool get isKomal => this == komalRe || this == komalGa || this == komalDha || this == komalNi;

  bool get isTivra => this == tivraMa;

  static Swar fromAscii(String letter) => values.firstWhere(
    (s) => s.ascii == letter,
    orElse: () => throw ArgumentError.value(letter, 'letter', 'not a swar'),
  );
}

/// A swar in a specific octave. [octave] is 0 for madhya, -1 for mandra,
/// +1 for taar, and so on.
class Pitch {
  const Pitch(this.swar, [this.octave = 0]);

  final Swar swar;
  final int octave;

  /// ASCII notation: `.N`, `S`, `S'`.
  String get ascii {
    final prefix = octave < 0 ? '.' * -octave : '';
    final suffix = octave > 0 ? "'" * octave : '';
    return '$prefix${swar.ascii}$suffix';
  }

  String get saptakName => switch (octave) {
    -1 => 'mandra',
    0 => 'madhya',
    1 => 'taar',
    _ => octave < 0 ? 'ati-mandra' : 'ati-taar',
  };

  @override
  bool operator ==(Object other) => other is Pitch && other.swar == swar && other.octave == octave;

  @override
  int get hashCode => Object.hash(swar, octave);

  @override
  String toString() => ascii;
}
