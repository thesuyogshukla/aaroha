import 'dart:math' as math;

import 'swar.dart';

/// Cents from Sa for each swar. Table-driven so alternatives can be added
/// (docs/02-music-model.md).
class Tuning {
  const Tuning(this.name, this._cents);

  final String name;
  final List<double> _cents;

  static const equal = Tuning('Equal temperament', [
    0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, //
  ]);

  static const just = Tuning('Just intonation', [
    0, 111.73, 203.91, 315.64, 386.31, 498.04, //
    590.22, 701.96, 813.69, 884.36, 1017.60, 1088.27,
  ]);

  double centsOfSwar(Swar swar) => _cents[swar.index];

  double centsOf(Pitch pitch) => centsOfSwar(pitch.swar) + 1200.0 * pitch.octave;

  /// The pitch nearest to [cents] (from Sa), and the deviation from it.
  ({Pitch pitch, double deviation}) nearest(double cents) {
    final baseOctave = (cents / 1200).floor();
    Pitch? best;
    var bestDistance = double.infinity;
    for (var octave = baseOctave - 1; octave <= baseOctave + 1; octave++) {
      for (final swar in Swar.values) {
        final candidate = Pitch(swar, octave);
        final distance = (cents - centsOf(candidate)).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          best = candidate;
        }
      }
    }
    return (pitch: best!, deviation: cents - centsOf(best));
  }
}

/// Cents of [hz] relative to [saHz].
double centsFromSa(double hz, double saHz) => 1200 * math.log(hz / saHz) / math.ln2;

/// Frequency [cents] above [saHz].
double hzFromCents(double cents, double saHz) => saHz * math.pow(2, cents / 1200);
