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
/// [maxNotes] notes (whole groups only, at least one; never mixing up and
/// down).
List<Drill> alankarRounds(Alankar alankar, List<Pitch> up, List<Pitch> down, {int maxNotes = 4}) {
  final walk = alankar.walk(up, down);
  // As many whole groups per round as fit, spread evenly: 8 single notes
  // in rounds of up to 6 are 4 + 4, not 6 + 2.
  List<Drill> chunk(List<List<Pitch>> groups, String label) {
    if (groups.isEmpty) return const [];
    final perRound = math.max(1, maxNotes ~/ alankar.pattern.length);
    final rounds = (groups.length / perRound).ceil();
    return [
      for (var k = 0; k < rounds; k++)
        (
          label: label,
          pitches: [
            for (final g in groups.sublist(
              (k * groups.length / rounds).round(),
              ((k + 1) * groups.length / rounds).round(),
            ))
              ...g,
          ],
        ),
    ];
  }

  return [...chunk(walk.up, 'Aaroh'), ...chunk(walk.down, 'Avaroh')];
}

/// Splits [phrase] into pieces of up to [maxNotes] notes. Parts between
/// `,` breaks are joined while they fit. A part still longer than
/// [maxNotes] is cut into near-equal pieces that share a note, so the line
/// carries on: S R G P D S' in pieces of 4 is S R G P, then P D S'.
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
      out.addAll(_cut(part, maxNotes));
    }
  }
  return out;
}

/// [run] in near-equal overlapping pieces of up to [maxNotes] (at least 2).
List<List<Pitch>> _cut(List<Pitch> run, int maxNotes) {
  final max = math.max(2, maxNotes);
  if (run.length <= max) return [List.of(run)];
  final steps = run.length - 1;
  final pieces = (steps / (max - 1)).ceil();
  final out = <List<Pitch>>[];
  var from = 0;
  for (var k = 0; k < pieces; k++) {
    final to = ((k + 1) * steps / pieces).round();
    out.add(run.sublist(from, to + 1));
    from = to;
  }
  return out;
}

/// Raga practice: the aaroh, then the avaroh (each piece in order), then the
/// raga's pakad and chalan phrases (and the aaroh and avaroh again) at
/// random, never the same phrase twice in a row. Phrases are cut to
/// [maxNotes] with [splitAtBreaks]; phrases outside [low]..[high] are left
/// out. [maxNotes] can change between rounds (the phrase level, docs/05 §9).
class RagaDrill {
  RagaDrill(
    this.raga, {
    Pitch low = const Pitch(Swar.pa, -1),
    Pitch high = const Pitch(Swar.pa, 1),
    Tuning tuning = Tuning.equal,
    int maxNotes = 8,
    math.Random? random,
  }) : _low = low,
       _high = high,
       _tuning = tuning,
       _random = random ?? math.Random() {
    this.maxNotes = maxNotes;
  }

  final Raga raga;
  final Pitch _low, _high;
  final Tuning _tuning;
  final math.Random _random;
  late List<Drill> pool;
  late int _maxNotes;
  int _opening = 0;
  Drill? _last;

  int get maxNotes => _maxNotes;
  set maxNotes(int value) {
    _maxNotes = value;
    List<Drill> drills(String label, Phrase p) => [
      for (final ps in splitAtBreaks(p, maxNotes: value)) (label: label, pitches: ps),
    ];
    bool fits(List<Pitch> ps) => ps.every(
      (p) =>
          _tuning.centsOf(p) >= _tuning.centsOf(_low) &&
          _tuning.centsOf(p) <= _tuning.centsOf(_high),
    );
    pool = [
      ...drills('Aaroh', raga.aaroh),
      ...drills('Avaroh', raga.avaroh),
      for (final p in raga.pakad) ...drills('Pakad', p),
      for (final p in raga.chalan) ...drills('Chalan', p),
    ].where((d) => fits(d.pitches)).toList();
    if (pool.isEmpty) throw ArgumentError('no phrase of ${raga.name} fits the flute');
  }

  Drill next() {
    final opening = [
      for (final d in pool)
        if (d.label == 'Aaroh' || d.label == 'Avaroh') d,
    ];
    if (_opening < opening.length) return _last = opening[_opening++];
    if (pool.length == 1) return _last = pool.single;
    Drill d;
    var tries = 0;
    do {
      d = pool[_random.nextInt(pool.length)];
    } while (_last != null && _samePitches(d.pitches, _last!.pitches) && ++tries < 50);
    return _last = d;
  }

  static bool _samePitches(List<Pitch> a, List<Pitch> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
