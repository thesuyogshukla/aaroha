import 'package:aaroha_core/aaroha_core.dart';

/// Outcome of holding Sa for calibration.
sealed class SaCalibration {}

class SaMeasured extends SaCalibration {
  SaMeasured(this.hz, this.spreadCents, this.centsFromNominal);
  final double hz;

  /// Interquartile spread of the held note; above ~20 c the hold was unsteady.
  final double spreadCents;

  /// Offset from the flute's nominal key, octave ignored.
  final double centsFromNominal;

  bool get steady => spreadCents <= 20;
}

class SaTooShort extends SaCalibration {}

/// The note held was not this flute's Sa (more than 100 c from its key).
class SaWrongKey extends SaCalibration {
  SaWrongKey(this.centsFromNominal);
  final double centsFromNominal;
}

/// Collects ~3 s of the player holding Sa (docs/02-music-model.md): the
/// median of the middle half becomes the flute's Sa. Players should hold it
/// with a relaxed, normal breath, since a flute's pitch rises with breath
/// pressure (decisions.md D23).
class SaCalibrator {
  SaCalibrator(this.flute, {this.frameCount = 300});

  final FluteKey flute;

  /// Frames to collect (100 per second).
  final int frameCount;

  final _hz = <double>[];
  int _seen = 0;

  double get progress => (_seen / frameCount).clamp(0, 1);
  bool get done => _seen >= frameCount;

  /// Feeds tracker frames; returns the result once enough have been seen.
  SaCalibration? feed(List<PitchFrame> frames) {
    if (done) return null;
    for (final f in frames) {
      // Start counting once the note begins, so a slow start doesn't count.
      final voiced = f.hz > 0 && f.confidence >= 0.85;
      if (_hz.isEmpty && !voiced) continue;
      _seen++;
      if (voiced) _hz.add(f.hz);
      if (done) return _result();
    }
    return null;
  }

  SaCalibration _result() {
    if (_hz.length < frameCount / 3) return SaTooShort();
    final middle = _hz.sublist(_hz.length ~/ 4, _hz.length * 3 ~/ 4)..sort();
    final hz = middle[middle.length ~/ 2];
    final q1 = middle[middle.length ~/ 4], q3 = middle[middle.length * 3 ~/ 4];
    final spread = centsFromSa(q3, q1);
    final offset = centsFromSa(hz, flute.nominalSaHz);
    final classOffset = offset - 1200 * (offset / 1200).round();
    if (classOffset.abs() > 100) return SaWrongKey(classOffset);
    return SaMeasured(hz, spread, classOffset);
  }
}
