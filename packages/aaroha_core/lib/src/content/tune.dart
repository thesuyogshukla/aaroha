import 'dart:math' as math;

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
/// the header names the taal; bars aren't checked against it, since a line
/// may start anywhere in the cycle. Returns the tune, or the problems.
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
    lines.add(parsed.phrase!);
  }
  if (title.trim().isEmpty) problems.add(const TuneProblem('give the tune a title', 1));
  if (lines.isEmpty && problems.isEmpty) {
    problems.add(const TuneProblem('write at least one line of notes', 1));
  }
  if (problems.isNotEmpty) return (tune: null, problems: problems);
  return (tune: Tune(title: title.trim(), lines: lines, header: header), problems: problems);
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
/// line longer than [maxNotes] is cut into pieces as raga phrases are
/// ([splitAtBreaks]), in order. Lines outside the flute's range are left
/// out. [maxNotes] can change between rounds (the phrase level).
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
    final pieces = <({Drill drill, int line})>[
      for (final i in _playable)
        ...() {
          final parts = splitAtBreaks(tune.lines[i], maxNotes: math.max(2, value));
          return [
            for (var k = 0; k < parts.length; k++)
              (
                drill: (
                  label: parts.length == 1 ? 'Line ${i + 1}' : 'Line ${i + 1}, part ${k + 1}',
                  phrase: parts[k],
                ),
                line: i + 1,
              ),
          ];
        }(),
    ];
    _pieces = [for (final p in pieces) p.drill];
    _lines = [for (final p in pieces) p.line];
    _next = _line == null ? 0 : math.max(0, _lines.indexOf(_line!));
  }

  List<int> _lines = const [];

  /// How many lines of the tune practice uses.
  int get playableLines => _playable.length;

  Drill next() {
    final k = _next++ % _pieces.length;
    _line = _lines[k];
    return _pieces[k];
  }
}
