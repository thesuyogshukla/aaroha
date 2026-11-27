import 'package:yaml/yaml.dart';

import '../model/phrase.dart';
import '../model/swar.dart';
import '../notation/parser.dart';

/// A raga definition from `content/ragas/*.yaml` (docs/06-content.md).
class Raga {
  const Raga({
    required this.id,
    required this.name,
    required this.swars,
    required this.aaroh,
    required this.avaroh,
    required this.source,
    required this.license,
    this.nameDev,
    this.thaat,
    this.pakad = const [],
    this.chalan = const [],
    this.vadi,
    this.samvadi,
    this.nyas = const [],
    this.drone = Swar.pa,
    this.time,
    this.notes,
  });

  final String id;
  final String name;
  final String? nameDev;
  final String? thaat;

  /// The swars the raga uses, in either direction.
  final List<Swar> swars;
  final Phrase aaroh;
  final Phrase avaroh;
  final List<Phrase> pakad;
  final List<Phrase> chalan;
  final Swar? vadi;
  final Swar? samvadi;
  final List<Swar> nyas;

  /// The tanpura's first string: Pa, shuddha Ma or Ni.
  final Swar drone;
  final String? time;

  /// Which version of the raga this file follows, and anything else to know.
  final String? notes;
  final String source;
  final String license;

  /// Swars used going up (from the aaroh), for walking an alankar. Turns in a
  /// vakra aaroh are skipped: only notes higher than the one before count,
  /// and only from Sa to taar Sa. Sa is always included.
  Set<Swar> get aarohSwars => _run(aaroh.pitches, up: true);

  /// Swars used coming down (from the avaroh), as for [aarohSwars].
  Set<Swar> get avarohSwars => _run(avaroh.pitches, up: false);

  static Set<Swar> _run(List<Pitch> pitches, {required bool up}) {
    int step(Pitch p) => p.octave * 12 + p.swar.semitone;
    final out = {Swar.sa};
    int? last;
    for (final p in pitches) {
      final s = step(p);
      if (last != null && (up ? s <= last : s >= last)) continue;
      last = s;
      if (s >= 0 && s <= 12) out.add(p.swar);
    }
    return out;
  }

  /// Parses one raga file. Throws [FormatException] naming the field at fault.
  factory Raga.fromYaml(String text) {
    final y = loadYaml(text);
    if (y is! YamlMap) throw const FormatException('a raga file must be a map');
    final id = _string(y, 'id');
    String where(String field) => 'raga $id, $field';

    Swar swar(Object? s, String field) {
      try {
        return Swar.fromAscii('$s');
      } on ArgumentError {
        throw FormatException('${where(field)}: "$s" is not a swar');
      }
    }

    final swars = [for (final s in _list(y, 'swars')) swar(s, 'swars')];
    Phrase phrase(Object? text, String field) {
      final Phrase p;
      try {
        p = parsePhrase('$text');
      } on FormatException catch (e) {
        throw FormatException('${where(field)}: ${e.message}');
      }
      for (final pitch in p.pitches) {
        if (!swars.contains(pitch.swar)) {
          throw FormatException('${where(field)}: ${pitch.ascii} is not in the raga\'s swars');
        }
      }
      if (p.pitches.isEmpty) throw FormatException('${where(field)}: no notes');
      return p;
    }

    final drone = y['drone'] == null ? Swar.pa : swar(y['drone'], 'drone');
    if (!const [Swar.pa, Swar.ma, Swar.ni].contains(drone)) {
      throw FormatException('${where('drone')}: must be P, m or N');
    }
    return Raga(
      id: id,
      name: _string(y, 'name'),
      nameDev: y['name_dev'] as String?,
      thaat: y['thaat'] as String?,
      swars: swars,
      aaroh: phrase(y['aaroh'], 'aaroh'),
      avaroh: phrase(y['avaroh'], 'avaroh'),
      pakad: [for (final p in _list(y, 'pakad', required: false)) phrase(p, 'pakad')],
      chalan: [for (final p in _list(y, 'chalan', required: false)) phrase(p, 'chalan')],
      vadi: y['vadi'] == null ? null : swar(y['vadi'], 'vadi'),
      samvadi: y['samvadi'] == null ? null : swar(y['samvadi'], 'samvadi'),
      nyas: [for (final s in _list(y, 'nyas', required: false)) swar(s, 'nyas')],
      drone: drone,
      time: y['time'] as String?,
      notes: y['notes'] as String?,
      source: _string(y, 'source'),
      license: _string(y, 'license'),
    );
  }
}

/// A pattern of scale-degree offsets applied from each degree in turn
/// (docs/06-content.md, Alankars).
class Alankar {
  const Alankar({required this.id, required this.name, required this.pattern});

  final String id;
  final String name;
  final List<int> pattern;

  /// Parses an alankar file: a map with `source`, `license` and `alankars`,
  /// a list of `{id, name, pattern}` maps (docs/06). A bare list, the format
  /// before the licence check, still reads.
  static List<Alankar> listFromYaml(String text) {
    final file = loadYaml(text);
    final y = file is YamlMap ? file['alankars'] : file;
    if (y is! YamlList) throw const FormatException('an alankar file must list its alankars');
    return [
      for (final a in y)
        if (a is YamlMap)
          Alankar(
            id: _string(a, 'id'),
            name: _string(a, 'name'),
            pattern: [for (final o in _list(a, 'pattern')) o as int],
          )
        else
          throw const FormatException('each alankar must be a map'),
    ];
  }

  /// The alankar walked up [up] and back down [down] (each sorted low to
  /// high), one group per starting degree. Going up, the pattern is applied
  /// from each degree while it fits; coming down it is mirrored, from the top.
  ({List<List<Pitch>> up, List<List<Pitch>> down}) walk(List<Pitch> up, List<Pitch> down) {
    final lo = pattern.reduce((a, b) => a < b ? a : b);
    final hi = pattern.reduce((a, b) => a > b ? a : b);
    return (
      up: [
        for (var i = 0; i < up.length; i++)
          if (i + lo >= 0 && i + hi < up.length) [for (final o in pattern) up[i + o]],
      ],
      down: [
        for (var i = down.length - 1; i >= 0; i--)
          if (i - hi >= 0 && i - lo < down.length) [for (final o in pattern) down[i - o]],
      ],
    );
  }
}

String _string(YamlMap y, String key) {
  final v = y[key];
  if (v is! String || v.isEmpty) throw FormatException('missing "$key"');
  return v;
}

List<Object?> _list(YamlMap y, String key, {bool required = true}) {
  final v = y[key];
  if (v == null && !required) return const [];
  if (v is! YamlList) throw FormatException('"$key" must be a list');
  return v;
}
