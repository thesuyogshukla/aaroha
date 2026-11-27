import 'package:yaml/yaml.dart';

import '../model/phrase.dart';
import '../model/taal.dart';
import '../notation/parser.dart';

/// A rhythm lesson from `content/rhythm/*.yaml` (docs/06, Rhythm): phrases
/// in one taal, written with their timing, easiest first.
class RhythmLesson {
  const RhythmLesson({
    required this.id,
    required this.name,
    required this.taal,
    required this.phrases,
    required this.source,
    required this.license,
  });

  final String id;
  final String name;
  final Taal taal;
  final List<Phrase> phrases;
  final String source;
  final String license;

  /// "Keherwa · Steps and holds".
  String get title => '${taal.label} · $name';

  /// Parses a lesson file: a `taal`, `source`, `license` and a list of
  /// `lessons`, each with an `id`, a `name` and its `phrases`. Each phrase
  /// must be whole vibhags of the taal, ending on a vibhag; its bars are
  /// checked against the taal (docs/03).
  static List<RhythmLesson> listFromYaml(String text) {
    final y = loadYaml(text);
    if (y is! YamlMap) throw const FormatException('a rhythm file must be a map');
    final taalId = _string(y, 'taal');
    final taal = Taal.byId(taalId) ?? (throw FormatException('unknown taal "$taalId"'));
    final source = _string(y, 'source');
    final license = _string(y, 'license');
    final lessons = y['lessons'];
    if (lessons is! YamlList) throw const FormatException('"lessons" must be a list');
    return [
      for (final l in lessons)
        if (l is YamlMap)
          RhythmLesson(
            id: _string(l, 'id'),
            name: _string(l, 'name'),
            taal: taal,
            source: source,
            license: license,
            phrases: [
              for (final p in (l['phrases'] as YamlList? ?? YamlList()))
                _phrase('$p', taal, _string(l, 'id')),
            ],
          )
        else
          throw const FormatException('each lesson must be a map'),
    ];
  }

  static Phrase _phrase(String text, Taal taal, String lesson) {
    // The header makes the parser check the bars against the taal.
    final checked = parseNotation('taal: ${taal.id}\n---\n$text');
    if (!checked.ok) {
      throw FormatException('$lesson: "$text": ${checked.errors.join('; ')}');
    }
    final phrase = parsePhrase(text);
    final matras = phrase.length;
    final into = matras.isInteger ? matras.numerator % taal.matras : -1;
    if (into != 0 && !taal.barOffsets.contains(into)) {
      throw FormatException('$lesson: "$text" doesn\'t end on a vibhag of ${taal.label}');
    }
    if (phrase.sounding.length < 2) {
      throw FormatException('$lesson: "$text" needs at least two notes');
    }
    return phrase;
  }
}

String _string(YamlMap y, String key) {
  final v = y[key];
  if (v is! String || v.isEmpty) throw FormatException('missing "$key"');
  return v;
}
