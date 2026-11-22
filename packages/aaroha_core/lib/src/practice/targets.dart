import 'dart:math' as math;

import '../model/swar.dart';
import '../model/tuning.dart';

/// Swar sets for practice presets (docs/01-product.md, difficulty axes).
enum SwarSet {
  saToPa('Sa to Pa', [Swar.sa, Swar.re, Swar.ga, Swar.ma, Swar.pa]),
  shuddha('All shuddha', [Swar.sa, Swar.re, Swar.ga, Swar.ma, Swar.pa, Swar.dha, Swar.ni]),
  all('With komal & tivra', Swar.values);

  const SwarSet(this.label, this.swars);
  final String label;
  final List<Swar> swars;
}

/// Which saptaks practice may use (always clipped to the flute's range).
enum SaptakRange {
  madhya('Madhya only', [0]),
  withMandra('Mandra + madhya', [-1, 0]),
  all('Mandra to taar', [-1, 0, 1]);

  const SaptakRange(this.label, this.octaves);
  final String label;
  final List<int> octaves;
}

/// Every pitch practice may ask for: the swar set in the chosen saptaks,
/// within [low]..[high] (the flute's playable range), sorted low to high.
List<Pitch> practicePitches(
  SwarSet set,
  SaptakRange range, {
  Pitch low = const Pitch(Swar.pa, -1),
  Pitch high = const Pitch(Swar.pa, 1),
  Tuning tuning = Tuning.equal,
}) {
  final lo = tuning.centsOf(low), hi = tuning.centsOf(high);
  final out = [
    for (final octave in range.octaves)
      for (final swar in set.swars)
        if (tuning.centsOf(Pitch(swar, octave)) >= lo && tuning.centsOf(Pitch(swar, octave)) <= hi)
          Pitch(swar, octave),
  ];
  out.sort((a, b) => tuning.centsOf(a).compareTo(tuning.centsOf(b)));
  return out;
}

/// Random targets for v0.1 practice: single swars, or short phrases that move
/// by small steps. Never asks for the same thing twice in a row. Adaptive
/// weighting by the player's mistakes comes in v0.2 (docs/05 §8).
class TargetGenerator {
  TargetGenerator(this.pitches, {math.Random? random}) : _random = random ?? math.Random() {
    if (pitches.isEmpty) throw ArgumentError('no pitches to practise');
  }

  final List<Pitch> pitches;
  final math.Random _random;
  List<Pitch>? _last;

  List<Pitch> single() {
    if (pitches.length == 1) return _remember([pitches.single]);
    Pitch next;
    do {
      next = pitches[_random.nextInt(pitches.length)];
    } while (_last != null && _last!.length == 1 && _last!.single == next);
    return _remember([next]);
  }

  /// A phrase of [minLength]..[maxLength] notes, each a step of one or two
  /// places up or down the allowed pitches, with no note repeated back to back.
  List<Pitch> phrase({int minLength = 2, int maxLength = 4}) {
    if (pitches.length == 1) return _remember([pitches.single]);
    for (;;) {
      final length = minLength + _random.nextInt(maxLength - minLength + 1);
      var index = _random.nextInt(pitches.length);
      final out = [pitches[index]];
      while (out.length < length) {
        final options = [
          for (final step in const [-2, -1, 1, 2])
            if (index + step >= 0 && index + step < pitches.length) index + step,
        ];
        index = options[_random.nextInt(options.length)];
        out.add(pitches[index]);
      }
      if (!_same(out, _last)) return _remember(out);
    }
  }

  List<Pitch> _remember(List<Pitch> target) => _last = target;

  static bool _same(List<Pitch> a, List<Pitch>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
