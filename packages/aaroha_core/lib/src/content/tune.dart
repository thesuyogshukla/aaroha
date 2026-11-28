import 'dart:math' as math;

import '../model/fraction.dart';
import '../model/phrase.dart';
import '../model/swar.dart';
import '../model/taal.dart';
import '../model/tuning.dart';
import '../notation/parser.dart';
import '../practice/material.dart';

/// A tune the player typed in (docs/06, Compositions): a bandish, a gat or
/// any tune, one line per row, in the notation of docs/03. Stored on the
/// phone only and never shipped: it may be someone else's work (CLAUDE.md
/// rule 9).
class Tune {
  const Tune({required this.title, required this.lines, this.header = const {}});

  final String title;

  /// One phrase per written line, with its timing.
  final List<Phrase> lines;

  /// `key: value` lines from the top of the text (`taal`, `tempo`, `raga`…).
  final Map<String, String> header;

  Taal? get taal => header['taal'] == null ? null : Taal.byId(header['taal']!);

  /// Where in the taal's cycle each line starts, in matras after sam (D57):
  /// the header's `start`, counted as in Bhatkhande notation (1 is sam), so
  /// `start: 9` in teentaal is 8. 0 without one.
  int get start => taal == null ? 0 : (int.tryParse(header['start'] ?? '') ?? 1) - 1;

  /// With a taal, practice clicks in it and judges timing (D57).
  bool get timed => taal != null;

  int get noteCount => lines.fold(0, (n, l) => n + l.sounding.length);
}

/// A problem in a tune's text, with a 1-based line and column in the whole
/// text as typed.
class TuneProblem {
  const TuneProblem(this.message, this.line, [this.column = 1]);
  final String message;
  final int line;
  final int column;

  @override
  String toString() => 'Line $line: $message';
}

/// Parses a tune as typed (D56). Optional `key: value` lines at the top
/// (and an optional `---` after them) are its header; every other line that
/// isn't blank or a `#` comment is one line of the tune. A known `taal` in
/// the header names the taal, and `start` the matra each line begins on (1
/// is sam). With a taal, every bar is checked against it from that start:
/// `|` where a vibhag begins, `||` on sam (D57). Returns the tune, or the
/// problems.
({Tune? tune, List<TuneProblem> problems}) parseTune(String title, String text) {
  final rows = text.split('\n');
  final header = <String, String>{};
  final problems = <TuneProblem>[];
  final headerLine = RegExp(r'^\s*([a-z][a-z_]*)\s*:\s*(.*?)\s*$');
  var i = 0;
  for (; i < rows.length; i++) {
    final row = rows[i].trim();
    if (row.isEmpty || row.startsWith('#')) continue;
    if (row == '---') {
      i++;
      break;
    }
    final m = headerLine.firstMatch(rows[i]);
    if (m == null) break;
    header[m[1]!] = m[2]!;
  }
  if (header['taal'] != null && Taal.byId(header['taal']!) == null) {
    problems.add(TuneProblem('unknown taal "${header['taal']}"', 1));
  }
  if (header['tempo'] != null && double.tryParse(header['tempo']!) == null) {
    problems.add(TuneProblem('tempo should be a number of matras a minute', 1));
  }
  final taal = header['taal'] == null ? null : Taal.byId(header['taal']!);
  var start = 0;
  if (header['start'] != null) {
    final n = int.tryParse(header['start']!);
    if (taal == null) {
      problems.add(const TuneProblem('start needs a taal: add a taal line above it', 1));
    } else if (n == null || n < 1 || n > taal.matras) {
      problems.add(TuneProblem('start is a matra of ${taal.label}, from 1 to ${taal.matras}', 1));
    } else {
      start = n - 1;
    }
  }

  final lines = <Phrase>[];
  for (; i < rows.length; i++) {
    final body = rows[i].split('#').first;
    if (body.trim().isEmpty) continue;
    final parsed = parseNotation(body);
    if (!parsed.ok) {
      for (final e in parsed.errors) {
        problems.add(TuneProblem(e.message, i + 1, e.column));
      }
      continue;
    }
    if (parsed.phrase!.sounding.isEmpty) {
      problems.add(TuneProblem('this line has no notes, only rests or bars', i + 1));
      continue;
    }
    if (taal != null) problems.addAll(_barProblems(parsed.phrase!, taal, start, i + 1));
    lines.add(parsed.phrase!);
  }
  if (title.trim().isEmpty) problems.add(const TuneProblem('give the tune a title', 1));
  if (lines.isEmpty && problems.isEmpty) {
    problems.add(const TuneProblem('write at least one line of notes', 1));
  }
  if (problems.isNotEmpty) return (tune: null, problems: problems);
  return (tune: Tune(title: title.trim(), lines: lines, header: header), problems: problems);
}

/// Bars of [line] that don't fall where [taal] has them, the line starting
/// [start] matras after sam (D57).
List<TuneProblem> _barProblems(Phrase line, Taal taal, int start, int row) {
  final vibhagStarts = {0, ...taal.barOffsets};
  final marks = [for (var v = 0, at = 0; v < taal.vibhags.length; at += taal.vibhags[v++]) at + 1];
  return [
    for (final bar in line.bars)
      if (!bar.at.isInteger)
        TuneProblem('a bar can only stand between matras', row)
      else if (bar.avartanEnd && (start + bar.at.numerator) % taal.matras != 0)
        TuneProblem(
          '"||" falls before matra ${(start + bar.at.numerator) % taal.matras + 1}, '
          'not before sam',
          row,
        )
      else if (!bar.avartanEnd && !vibhagStarts.contains((start + bar.at.numerator) % taal.matras))
        TuneProblem(
          '"|" falls before matra ${(start + bar.at.numerator) % taal.matras + 1}; '
          'vibhags of ${taal.label} begin on ${marks.join(', ')}',
          row,
        ),
  ];
}

/// [line], which starts [start] matras after sam, cut at the starts of
/// [taal]'s vibhags into pieces of up to [maxNotes] notes (at least one
/// vibhag each), never inside a note (D57). Unlike [splitAtBreaks], nothing
/// moves: each piece keeps its timing and says where in the cycle it starts.
List<({Phrase phrase, int start})> cutAtVibhags(
  Phrase line,
  Taal taal, {
  int start = 0,
  int maxNotes = 8,
}) {
  final length = line.length.isInteger ? line.length.numerator : line.length.floor() + 1;
  final vibhagStarts = {0, ...taal.barOffsets};
  bool insideANote(int m) => line.sounding.any((n) => n.start < Fraction(m) && n.end > Fraction(m));
  final cuts = [
    0,
    for (var m = 1; m < length; m++)
      if (vibhagStarts.contains((start + m) % taal.matras) && !insideANote(m)) m,
    length,
  ];
  int notesIn(int a, int b) =>
      line.sounding.where((n) => n.start >= Fraction(a) && n.start < Fraction(b)).length;

  final out = <({Phrase phrase, int start})>[];
  var from = 0;
  for (var k = 1; k < cuts.length; k++) {
    final last = k == cuts.length - 1;
    // Take the next vibhag too while the piece stays within maxNotes.
    if (!last && notesIn(cuts[from], cuts[k + 1]) <= maxNotes) continue;
    final piece = _piece(line, cuts[from], cuts[k]);
    if (piece != null) {
      out.add((phrase: piece.phrase, start: (start + piece.from) % taal.matras));
    }
    from = k;
  }
  return out;
}

/// The notes of [line] from matra [a] to [b], moved to start at 0, leading
/// silent matras dropped (so [from] can be later than [a]). Null if silent.
({Phrase phrase, int from})? _piece(Phrase line, int a, int b) {
  final inside = [
    for (final n in line.notes)
      if (n.start >= Fraction(a) && n.start < Fraction(b)) n,
  ];
  final firstNote = inside.where((n) => !n.isRest).firstOrNull;
  if (firstNote == null) return null;
  final from = firstNote.start.floor();
  final lastNote = inside.lastWhere((n) => !n.isRest);
  final notes = [
    for (final n in inside)
      if (n.start >= Fraction(from) && n.start <= lastNote.start)
        Note(
          pitch: n.pitch,
          start: n.start - Fraction(from),
          duration: n.duration,
          kan: n.kan,
          glideToNext: n.glideToNext && n != lastNote,
          breakBefore: n.breakBefore,
        ),
  ];
  // A rest fills the start of the first matra, and the end of the last.
  final out = [
    if (notes.first.start > Fraction.zero) Note(start: Fraction.zero, duration: notes.first.start),
    ...notes,
  ];
  final end = out.last.end;
  if (!end.isInteger) out.add(Note(start: end, duration: Fraction(end.floor() + 1) - end));
  return (phrase: Phrase(notes: out), from: from);
}

/// Lines of [tune] with a note outside [low]..[high]: they can't be played on
/// that flute, so practice leaves them out. 1-based line numbers.
List<int> linesOutOfRange(Tune tune, {required Pitch low, required Pitch high, Tuning? tuning}) {
  final t = tuning ?? Tuning.equal;
  final lo = t.centsOf(low), hi = t.centsOf(high);
  return [
    for (var i = 0; i < tune.lines.length; i++)
      if (tune.lines[i].pitches.any((p) => t.centsOf(p) < lo || t.centsOf(p) > hi)) i + 1,
  ];
}

/// Practising a tune (docs/08 M4): its lines in order, again and again. A
/// line longer than [maxNotes] is cut into pieces, in order: at vibhags for a
/// tune with a taal, keeping each piece's place in the cycle ([cutAtVibhags],
/// D57); as raga phrases are otherwise ([splitAtBreaks]). Lines outside the
/// flute's range are left out. [maxNotes] can change between rounds (the
/// phrase level).
class TuneDrill {
  TuneDrill(
    this.tune, {
    Pitch low = const Pitch(Swar.pa, -1),
    Pitch high = const Pitch(Swar.pa, 1),
    Tuning tuning = Tuning.equal,
    int maxNotes = 8,
  }) : _playable = [
         for (var i = 0; i < tune.lines.length; i++)
           if (!linesOutOfRange(
             Tune(title: tune.title, lines: [tune.lines[i]]),
             low: low,
             high: high,
             tuning: tuning,
           ).contains(1))
             i,
       ] {
    if (_playable.isEmpty) throw ArgumentError('no line of ${tune.title} fits the flute');
    this.maxNotes = maxNotes;
  }

  final Tune tune;

  /// Indexes of the lines the flute can play.
  final List<int> _playable;
  List<Drill> _pieces = const [];
  late int _maxNotes;
  int _next = 0;

  /// The line the last round came from, 1-based; null before the first.
  int? _line;

  int get maxNotes => _maxNotes;

  /// Changing the length starts again from the line being practised.
  set maxNotes(int value) {
    _maxNotes = value;
    final taal = tune.taal;
    final pieces = <({Drill drill, int line, int start})>[
      for (final i in _playable)
        ...() {
          final parts = taal != null
              ? cutAtVibhags(tune.lines[i], taal, start: tune.start, maxNotes: math.max(2, value))
              : [
                  for (final p in splitAtBreaks(tune.lines[i], maxNotes: math.max(2, value)))
                    (phrase: p, start: 0),
                ];
          return [
            for (var k = 0; k < parts.length; k++)
              (
                drill: (
                  label: parts.length == 1 ? 'Line ${i + 1}' : 'Line ${i + 1}, part ${k + 1}',
                  phrase: parts[k].phrase,
                ),
                line: i + 1,
                start: parts[k].start,
              ),
          ];
        }(),
    ];
    _pieces = [for (final p in pieces) p.drill];
    _lines = [for (final p in pieces) p.line];
    _starts = [for (final p in pieces) p.start];
    _next = _line == null ? 0 : math.max(0, _lines.indexOf(_line!));
  }

  List<int> _lines = const [];
  List<int> _starts = const [];

  /// Where in the taal's cycle the last round's phrase starts, in matras
  /// after sam (D57); 0 before the first round and for untimed tunes.
  int get lastStart => _lastStart;
  int _lastStart = 0;

  /// How many lines of the tune practice uses.
  int get playableLines => _playable.length;

  Drill next() {
    final k = _next++ % _pieces.length;
    _line = _lines[k];
    _lastStart = _starts[k];
    return _pieces[k];
  }
}
