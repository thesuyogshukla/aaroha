import 'dart:math' as math;

import '../content/raga.dart';
import '../model/phrase.dart';
import '../model/swar.dart';
import '../model/tuning.dart';
import 'targets.dart';

/// One round's target from real material, with what it is ("Aaroh", "Pakad").
typedef Drill = ({String label, List<Pitch> pitches});

/// Scale degrees for an alankar: [swars] in the chosen saptaks plus the Sa
/// above the top one, within [low]..[high], sorted low to high.
List<Pitch> scaleDegrees(
  Iterable<Swar> swars,
  SaptakRange range, {
  Pitch low = const Pitch(Swar.pa, -1),
  Pitch high = const Pitch(Swar.pa, 1),
  Tuning tuning = Tuning.equal,
}) {
  final top = range.octaves.reduce(math.max);
  final lo = tuning.centsOf(low), hi = tuning.centsOf(high);
  final out = {
    for (final octave in range.octaves)
      for (final swar in swars) Pitch(swar, octave),
    Pitch(Swar.sa, top + 1),
  }.where((p) => tuning.centsOf(p) >= lo && tuning.centsOf(p) <= hi).toList();
  out.sort((a, b) => tuning.centsOf(a).compareTo(tuning.centsOf(b)));
  return out;
}

/// An alankar session: the pattern walked up, then down, in rounds of up to
/// [maxNotes] notes (whole groups only; never mixing up and down).
List<Drill> alankarRounds(Alankar alankar, List<Pitch> up, List<Pitch> down, {int maxNotes = 4}) {
  final walk = alankar.walk(up, down);
  List<Drill> chunk(List<List<Pitch>> groups, String label) {
    final out = <Drill>[];
    var current = <Pitch>[];
    for (final g in groups) {
      if (current.isNotEmpty && current.length + g.length > maxNotes) {
        out.add((label: label, pitches: current));
        current = [];
      }
      current = [...current, ...g];
    }
    if (current.isNotEmpty) out.add((label: label, pitches: current));
    return out;
  }

  return [...chunk(walk.up, 'Aaroh'), ...chunk(walk.down, 'Avaroh')];
}

/// Splits [phrase] at its `,` breaks into pieces of up to [maxNotes] notes,
/// joining neighbouring parts while they fit. A part longer than [maxNotes]
/// with no break inside stays whole.
List<List<Pitch>> splitAtBreaks(Phrase phrase, {int maxNotes = 8}) {
  final parts = <List<Pitch>>[];
  for (final n in phrase.sounding) {
    if (parts.isEmpty || n.breakBefore) parts.add([]);
    parts.last.add(n.pitch!);
  }
  final out = <List<Pitch>>[];
  for (final part in parts) {
    if (out.isNotEmpty && out.last.length + part.length <= maxNotes) {
      out.last.addAll(part);
    } else {
      out.add([...part]);
    }
  }
  return out;
}

/// Raga practice: the aaroh, then the avaroh, then the raga's pakad and
/// chalan phrases (and the aaroh and avaroh again) at random, never the same
/// phrase twice in a row. Phrases longer than [maxNotes] are split at their
/// breaks; phrases outside [low]..[high] are left out.
class RagaDrill {
  RagaDrill(
    this.raga, {
    Pitch low = const Pitch(Swar.pa, -1),
    Pitch high = const Pitch(Swar.pa, 1),
    Tuning tuning = Tuning.equal,
    int maxNotes = 8,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    List<Drill> drills(String label, Phrase p) => [
      for (final ps in splitAtBreaks(p, maxNotes: maxNotes)) (label: label, pitches: ps),
    ];
    bool fits(List<Pitch> ps) => ps.every(
      (p) => tuning.centsOf(p) >= tuning.centsOf(low) && tuning.centsOf(p) <= tuning.centsOf(high),
    );
    pool = [
      ...drills('Aaroh', raga.aaroh),
      ...drills('Avaroh', raga.avaroh),
      for (final p in raga.pakad) ...drills('Pakad', p),
      for (final p in raga.chalan) ...drills('Chalan', p),
    ].where((d) => fits(d.pitches)).toList();
    if (pool.isEmpty) throw ArgumentError('no phrase of ${raga.name} fits the flute');
  }

  final Raga raga;
  late final List<Drill> pool;
  final math.Random _random;
  int _count = 0;
  int? _last;

  /// The aaroh and avaroh open the session, in order; then any phrase.
  Drill next() {
    int i;
    final opening = pool.indexWhere((d) => d.label == (_count == 0 ? 'Aaroh' : 'Avaroh'));
    if (_count < 2 && opening >= 0 && opening != _last) {
      i = opening;
    } else if (pool.length == 1) {
      i = 0;
    } else {
      do {
        i = _random.nextInt(pool.length);
      } while (i == _last);
    }
    _count++;
    _last = i;
    return pool[i];
  }
}
