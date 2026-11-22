import '../model/fraction.dart';
import '../model/phrase.dart';
import '../model/swar.dart';
import '../model/taal.dart';

/// A problem in notation text, with a 1-based line and column.
class NotationError {
  const NotationError(this.message, this.line, this.column);
  final String message;
  final int line;
  final int column;

  @override
  String toString() => '$line:$column: $message';
}

class NotationResult {
  const NotationResult(this.phrase, this.errors);

  /// Null when there were errors.
  final Phrase? phrase;
  final List<NotationError> errors;

  bool get ok => errors.isEmpty;
}

/// Parses notation (docs/03-notation.md) and throws [FormatException] listing
/// every error. Use [parseNotation] to get the errors as data.
Phrase parsePhrase(String text) {
  final result = parseNotation(text);
  if (!result.ok) throw FormatException(result.errors.join('\n'));
  return result.phrase!;
}

NotationResult parseNotation(String text) => _Parser(text).run();

class _Token {
  const _Token(this.text, this.line, this.column);
  final String text;
  final int line;
  final int column;
}

enum _Kind { pitch, hold, rest }

class _Position {
  _Position(this.kind, {this.pitch, this.kan});
  final _Kind kind;
  final Pitch? pitch;
  final Pitch? kan;
  bool glide = false;
}

final _headerLine = RegExp(r'^\s*([a-z][a-z_]*)\s*:\s*(.*?)\s*$');

class _Parser {
  _Parser(this.text);

  final String text;
  final errors = <NotationError>[];
  final header = <String, String>{};
  final notes = <Note>[];
  final bars = <Bar>[];

  NotationResult run() {
    final lines = text.split('\n');
    var bodyStart = _readHeader(lines);
    final tokens = <_Token>[];
    for (var l = bodyStart; l < lines.length; l++) {
      final line = lines[l].split('#').first;
      for (final m in RegExp(r'\S+').allMatches(line)) {
        tokens.add(_Token(m.group(0)!, l + 1, m.start + 1));
      }
    }

    var position = Fraction.zero;
    var pendingBreak = false;
    for (final token in tokens) {
      switch (token.text) {
        case ',':
          pendingBreak = true;
        case '|':
          bars.add(Bar(position));
        case '||':
          bars.add(Bar(position, avartanEnd: true));
        default:
          final positions = _parseMatra(token);
          if (positions == null) break;
          final share = Fraction(1, positions.length);
          for (var i = 0; i < positions.length; i++) {
            final p = positions[i];
            final start = position + share * Fraction(i);
            switch (p.kind) {
              case _Kind.pitch:
                notes.add(
                  Note(
                    pitch: p.pitch,
                    start: start,
                    duration: share,
                    kan: p.kan,
                    glideToNext: p.glide,
                    breakBefore: pendingBreak,
                  ),
                );
                pendingBreak = false;
              case _Kind.hold:
                if (notes.isEmpty) {
                  _error('"-" holds a note, but no note comes before it', token);
                } else if (i == 0 && pendingBreak) {
                  _error('a phrase break "," can\'t be followed by a hold "-"', token);
                } else {
                  notes.last = notes.last.copyWith(duration: notes.last.duration + share);
                  if (p.glide && notes.last.isRest) {
                    _error('"~" (meend) must follow a note', token);
                  } else if (p.glide) {
                    notes.last = notes.last.copyWith(glideToNext: true);
                  }
                }
              case _Kind.rest:
                if (!pendingBreak &&
                    notes.isNotEmpty &&
                    notes.last.isRest &&
                    notes.last.end == start) {
                  notes.last = notes.last.copyWith(duration: notes.last.duration + share);
                } else {
                  notes.add(Note(start: start, duration: share, breakBefore: pendingBreak));
                  pendingBreak = false;
                }
            }
          }
          position += Fraction.one;
      }
    }

    _checkTaal(position);

    if (errors.isNotEmpty) return NotationResult(null, errors);
    return NotationResult(Phrase(notes: notes, bars: bars, header: header), const []);
  }

  /// Reads `key: value` lines and an optional `---`. Returns the body's
  /// first line index.
  int _readHeader(List<String> lines) {
    for (var l = 0; l < lines.length; l++) {
      final line = lines[l].split('#').first;
      if (line.trim().isEmpty) continue;
      if (line.trim() == '---') return l + 1;
      final m = _headerLine.firstMatch(line);
      if (m == null) return l;
      header[m.group(1)!] = m.group(2)!;
      if (m.group(1) == 'taal' && Taal.byId(m.group(2)!) == null) {
        errors.add(NotationError('unknown taal "${m.group(2)}"', l + 1, 1));
      }
    }
    return lines.length;
  }

  /// Splits one matra token into positions, or reports errors and returns null.
  List<_Position>? _parseMatra(_Token token) {
    final s = token.text;
    final out = <_Position>[];
    var i = 0;
    var ok = true;

    void fail(String message, int at) {
      errors.add(NotationError(message, token.line, token.column + at));
      ok = false;
    }

    // Reads `.`* swar `'`* starting at i; returns null on error.
    Pitch? readPitch() {
      final at = i;
      var down = 0;
      while (i < s.length && s[i] == '.') {
        down++;
        i++;
      }
      if (i >= s.length || !_isSwar(s[i])) {
        fail('expected a swar (S r R g G m M P d D n N)', at);
        return null;
      }
      final swar = Swar.fromAscii(s[i++]);
      var up = 0;
      while (i < s.length && s[i] == "'") {
        up++;
        i++;
      }
      if (down > 0 && up > 0) {
        fail('a swar can\'t be both mandra and taar', at);
        return null;
      }
      return Pitch(swar, up - down);
    }

    while (i < s.length && ok) {
      final c = s[i];
      if (c == '-') {
        out.add(_Position(_Kind.hold));
        i++;
      } else if (c == '_') {
        out.add(_Position(_Kind.rest));
        i++;
      } else if (c == '~') {
        if (out.isEmpty || out.last.kind == _Kind.rest) {
          fail('"~" (meend) must follow a note', i);
        } else if (i + 1 >= s.length) {
          fail('"~" (meend) needs a note after it in the same matra', i);
        } else {
          out.last.glide = true;
        }
        i++;
      } else if (c == '{') {
        final close = s.indexOf('}', i);
        if (close < 0) {
          fail('"{" (kan) is not closed', i);
          break;
        }
        final start = i;
        i++;
        final kan = readPitch();
        if (!ok) break;
        if (i != close) {
          fail('a kan holds exactly one swar', start);
          break;
        }
        i++;
        if (i >= s.length || s[i] == '-' || s[i] == '_' || s[i] == '~' || s[i] == '{') {
          fail('a kan must come right before a note', start);
          break;
        }
        final pitch = readPitch();
        if (pitch != null) out.add(_Position(_Kind.pitch, pitch: pitch, kan: kan));
      } else if (c == '.' || _isSwar(c)) {
        final pitch = readPitch();
        if (pitch != null) out.add(_Position(_Kind.pitch, pitch: pitch));
      } else if (c == '|' || c == ',') {
        fail('"$c" must be separated from notes by spaces', i);
      } else {
        fail('unexpected "$c"', i);
      }
    }
    if (ok) {
      for (var k = 0; k + 1 < out.length; k++) {
        if (out[k].glide && out[k + 1].kind != _Kind.pitch) {
          fail('"~" (meend) must lead into a note', 0);
        }
      }
    }
    return ok ? out : null;
  }

  void _checkTaal(Fraction total) {
    final taal = Taal.byId(header['taal'] ?? '');
    if (taal == null) return;
    final line = _bodyLine();
    var avartanStart = 0;
    final ends = [
      for (final b in bars)
        if (b.avartanEnd) b.at.floor(),
    ];
    for (final end in ends) {
      final length = end - avartanStart;
      if (length != taal.matras) {
        errors.add(
          NotationError(
            'avartan ending at matra $end has $length matras; ${taal.id} has ${taal.matras}',
            line,
            1,
          ),
        );
      }
      avartanStart = end;
    }
    final trailing = total.floor() - avartanStart;
    if (trailing > taal.matras) {
      errors.add(
        NotationError(
          '${taal.id} has ${taal.matras} matras per avartan; mark avartans with "||"',
          line,
          1,
        ),
      );
    }
    for (final b in bars.where((b) => !b.avartanEnd)) {
      final offset = b.at.floor() - _avartanStartFor(b.at.floor(), ends);
      if (!taal.barOffsets.contains(offset)) {
        errors.add(
          NotationError(
            'vibhag bar after matra $offset of the avartan; ${taal.id} divides at '
            '${taal.barOffsets.join(', ')}',
            line,
            1,
          ),
        );
      }
    }
  }

  int _avartanStartFor(int at, List<int> ends) {
    var start = 0;
    for (final e in ends) {
      if (e <= at) start = e;
    }
    return start;
  }

  int _bodyLine() {
    final lines = text.split('\n');
    for (var l = 0; l < lines.length; l++) {
      final t = lines[l].split('#').first.trim();
      if (t.isNotEmpty && t != '---' && !_headerLine.hasMatch(t)) return l + 1;
    }
    return 1;
  }

  void _error(String message, _Token token) =>
      errors.add(NotationError(message, token.line, token.column));
}

bool _isSwar(String c) => 'SrRgGmMPdDnN'.contains(c);
