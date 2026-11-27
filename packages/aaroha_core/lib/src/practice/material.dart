import 'dart:math' as math;

import '../content/raga.dart';
import '../content/rhythm_lesson.dart';
import '../model/fraction.dart';
import '../model/phrase.dart';
import '../model/swar.dart';
import '../model/tuning.dart';
import 'targets.dart';

/// One round's target from real material, with what it is ("Aaroh", "Pakad").
/// The phrase keeps its written timing, which the call plays (docs/08 M3-A).
typedef Drill = ({String label, Phrase phrase});

extension DrillPitches on Drill {
  /// The swars to play, in order, without their timing.
  List<Pitch> get pitches => phrase.pitches;
}

/// [pitches] one matra each: the timing of material written without
/// durations (random phrases, alankars, untimed raga phrases).
Phrase evenPhrase(List<Pitch> pitches) => Phrase(
  notes: [
    for (var i = 0; i < pitches.length; i++)
      Note(pitch: pitches[i], start: Fraction(i), duration: Fraction.one),
  ],
);

/// True when every note of [phrase] is one matra, back to back, with no
/// rests or bars: how all material sounded before durations (docs/08 M3-A).
bool isEven(Phrase phrase) {
  if (phrase.bars.isNotEmpty) return false;
  for (var i = 0; i < phrase.notes.length; i++) {
    final n = phrase.notes[i];
    if (n.isRest || n.start != Fraction(i) || n.duration != Fraction.one) return false;
  }
  return true;
}

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
          phrase: evenPhrase([
            for (final g in groups.sublist(
              (k * groups.length / rounds).round(),
              ((k + 1) * groups.length / rounds).round(),
            ))
              ...g,
          ]),
        ),
    ];
  }

  return [...chunk(walk.up, 'Aaroh'), ...chunk(walk.down, 'Avaroh')];
}

/// Splits [phrase] into pieces of up to [maxNotes] notes, each keeping its
/// written timing. Parts between `,` breaks are joined while they fit, the
/// second carrying on where the first ends. A part still longer than
/// [maxNotes] is cut into near-equal pieces that share a note, so the line
/// carries on: S R G P D S' in pieces of 4 is S R G P, then P D S'.
List<Phrase> splitAtBreaks(Phrase phrase, {int maxNotes = 8}) {
  // Each part: its notes and rests, from the first note to the last.
  final parts = <List<Note>>[];
  for (final n in phrase.notes) {
    if (n.isRest) {
      if (parts.isNotEmpty && !n.breakBefore) parts.last.add(n);
      continue;
    }
    if (parts.isEmpty || n.breakBefore) parts.add([]);
    parts.last.add(n);
  }
  for (final part in parts) {
    while (part.last.isRest) {
      part.removeLast();
    }
  }
  final out = <List<Note>>[];
  int count(List<Note> notes) => notes.where((n) => !n.isRest).length;
  for (final part in parts) {
    if (out.isNotEmpty && count(out.last) + count(part) <= maxNotes) {
      out.last.addAll(_shift(part, out.last.last.end - part.first.start));
    } else {
      out.addAll(_cut(part, maxNotes));
    }
  }
  return [for (final notes in out) _rebase(notes)];
}

/// [run] in near-equal overlapping pieces of up to [maxNotes] notes (at
/// least 2), rests between them kept.
List<List<Note>> _cut(List<Note> run, int maxNotes) {
  final max = math.max(2, maxNotes);
  final sounding = [
    for (var i = 0; i < run.length; i++)
      if (!run[i].isRest) i,
  ];
  if (sounding.length <= max) return [List.of(run)];
  final steps = sounding.length - 1;
  final pieces = (steps / (max - 1)).ceil();
  final out = <List<Note>>[];
  var from = 0;
  for (var k = 0; k < pieces; k++) {
    final to = ((k + 1) * steps / pieces).round();
    out.add(run.sublist(sounding[from], sounding[to] + 1));
    from = to;
  }
  return out;
}

List<Note> _shift(List<Note> notes, Fraction by) => [
  for (final n in notes)
    Note(
      pitch: n.pitch,
      start: n.start + by,
      duration: n.duration,
      kan: n.kan,
      glideToNext: n.glideToNext,
    ),
];

/// [notes] as a phrase of its own: moved so its first matra is matra 0,
/// keeping where each note falls inside its matra. Rests fill the start of
/// the first matra and the end of the last, so every matra is whole.
Phrase _rebase(List<Note> notes) {
  final from = Fraction(notes.first.start.floor());
  final moved = _shift(notes, Fraction.zero - from);
  final out = [
    if (moved.first.start > Fraction.zero) Note(start: Fraction.zero, duration: moved.first.start),
    ...moved,
  ];
  // A glide can't lead out of the piece.
  if (out.last.glideToNext) out[out.length - 1] = out.last.copyWith(glideToNext: false);
  final end = out.last.end;
  if (!end.isInteger) out.add(Note(start: end, duration: Fraction(end.floor() + 1) - end));
  return Phrase(notes: out);
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
      for (final piece in splitAtBreaks(p, maxNotes: value)) (label: label, phrase: piece),
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

/// Rhythm practice (docs/08 M3-E): the lesson's phrases in order, as
/// written (easiest first), then at random, never the same phrase twice in
/// a row. Phrases aren't cut to the phrase level: their length is part of
/// the rhythm.
class RhythmDrill {
  RhythmDrill(this.lesson, {math.Random? random}) : _random = random ?? math.Random() {
    if (lesson.phrases.isEmpty) throw ArgumentError('${lesson.id} has no phrases');
  }

  final RhythmLesson lesson;
  final math.Random _random;
  int _next = 0;
  int? _last;

  Drill next() {
    final phrases = lesson.phrases;
    int i;
    if (_next < phrases.length) {
      i = _next++;
    } else if (phrases.length == 1) {
      i = 0;
    } else {
      do {
        i = _random.nextInt(phrases.length);
      } while (i == _last);
    }
    _last = i;
    return (label: lesson.name, phrase: phrases[i]);
  }
}
