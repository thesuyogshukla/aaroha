import '../model/phrase.dart';
import 'layout.dart';

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
  out.write(layoutNotation(phrase).join(' '));
  return out.toString();
}
