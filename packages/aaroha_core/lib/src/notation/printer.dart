import '../model/fraction.dart';
import '../model/phrase.dart';

/// Canonical notation text for [phrase] (docs/03-notation.md). Parsing the
/// result gives back an equal phrase.
String printNotation(Phrase phrase) {
  final out = StringBuffer();
  if (phrase.header.isNotEmpty) {
    for (final e in phrase.header.entries) {
      out.writeln('${e.key}: ${e.value}');
    }
    out.writeln('---');
  }

  final tokens = <String>[];
  final matras = _ceil(phrase.length);
  for (var m = 0; m <= matras; m++) {
    final at = Fraction(m);
    for (final b in phrase.bars.where((b) => b.at == at)) {
      tokens.add(b.avartanEnd ? '||' : '|');
    }
    if (m == matras) break;
    final inMatra = [
      for (final n in phrase.notes)
        if (n.start < at + Fraction.one && n.end > at) n,
    ];
    if (inMatra.isNotEmpty && inMatra.first.start == at && inMatra.first.breakBefore) {
      tokens.add(',');
    }
    tokens.add(_matra(at, inMatra));
  }
  out.write(tokens.join(' '));
  return out.toString();
}

String _matra(Fraction at, List<Note> notes) {
  // Enough equal positions to place every note boundary inside the matra.
  var positions = 1;
  for (final n in notes) {
    for (final t in [n.start, n.end]) {
      if (t > at && t < at + Fraction.one) positions = lcm(positions, (t - at).denominator);
    }
  }
  final buffer = StringBuffer();
  for (var j = 0; j < positions; j++) {
    final t = at + Fraction(j, positions);
    final note = notes.firstWhere((n) => n.start <= t && n.end > t);
    if (note.isRest) {
      buffer.write('_');
    } else if (note.start == t) {
      if (note.kan != null) buffer.write('{${note.kan!.ascii}}');
      buffer.write(note.pitch!.ascii);
    } else {
      buffer.write('-');
    }
    final next = at + Fraction(j + 1, positions);
    if (note.glideToNext && note.end == next) buffer.write('~');
  }
  return buffer.toString();
}

int _ceil(Fraction f) => f.isInteger ? f.numerator : f.floor() + 1;
