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

/// Practice targets: single swars, or short phrases that move by small
/// steps. Never asks for the same thing twice in a row.
///
/// With [weightOf] (smart drilling, docs/05 §8), swars are picked in
/// proportion to their weight, and phrases start from a weighted swar. With
/// [pairs] (confused pairs, most confused first), a [contrastChance] share of
/// targets is a contrast drill: the two swars back to back, as two single
/// rounds or one two-note phrase.
class TargetGenerator {
  TargetGenerator(
    this.pitches, {
    math.Random? random,
    this.weightOf,
    this.pairs,
    this.contrastChance = 0.2,
  }) : _random = random ?? math.Random() {
    if (pitches.isEmpty) throw ArgumentError('no pitches to practise');
  }

  final List<Pitch> pitches;
  final double Function(Pitch)? weightOf;
  final List<(Pitch, Pitch)> Function()? pairs;
  final double contrastChance;
  final math.Random _random;
  List<Pitch>? _last;
  final _queue = <List<Pitch>>[];

  List<Pitch> single() {
    if (pitches.length == 1) return _remember([pitches.single]);
    if (_queue.isNotEmpty) return _remember(_queue.removeAt(0));
    final pair = _contrastPair();
    if (pair != null) {
      _queue.add([pair.$2]);
      return _remember([pair.$1]);
    }
    Pitch next;
    var tries = 0;
    do {
      next = _pick();
    } while (_last != null && _last!.length == 1 && _last!.single == next && ++tries < 50);
    return _remember([next]);
  }

  /// A phrase of [minLength]..[maxLength] notes, each a step of one or two
  /// places up or down the allowed pitches, with no note repeated back to back.
  List<Pitch> phrase({int minLength = 2, int maxLength = 4}) {
    if (pitches.length == 1) return _remember([pitches.single]);
    if (minLength <= 2) {
      final pair = _contrastPair();
      if (pair != null) return _remember([pair.$1, pair.$2]);
    }
    for (;;) {
      final length = minLength + _random.nextInt(maxLength - minLength + 1);
      var index = pitches.indexOf(_pick());
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

  /// A pitch at random, in proportion to [weightOf] when given.
  Pitch _pick() {
    final weightOf = this.weightOf;
    if (weightOf == null) return pitches[_random.nextInt(pitches.length)];
    final weights = [for (final p in pitches) math.max(0.0, weightOf(p))];
    final total = weights.fold(0.0, (a, b) => a + b);
    if (total <= 0) return pitches[_random.nextInt(pitches.length)];
    var r = _random.nextDouble() * total;
    for (var i = 0; i < pitches.length; i++) {
      r -= weights[i];
      if (r < 0) return pitches[i];
    }
    return pitches.last;
  }

  /// Sometimes, one of the top three confused pairs within the allowed set.
  (Pitch, Pitch)? _contrastPair() {
    final pairs = this.pairs;
    if (pairs == null || _random.nextDouble() >= contrastChance) return null;
    final allowed = pitches.toSet();
    final candidates = [
      for (final p in pairs())
        if (p.$1 != p.$2 && allowed.contains(p.$1) && allowed.contains(p.$2)) p,
    ].take(3).toList();
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
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
