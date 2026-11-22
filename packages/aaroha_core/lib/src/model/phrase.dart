import 'fraction.dart';
import 'swar.dart';
import 'taal.dart';

/// A note or rest in a phrase. Times are in matras from the phrase start.
class Note {
  const Note({
    this.pitch,
    required this.start,
    required this.duration,
    this.kan,
    this.glideToNext = false,
    this.breakBefore = false,
  });

  /// Null for a rest.
  final Pitch? pitch;
  final Fraction start;
  final Fraction duration;

  /// Grace note touched just before this one (docs/03, v0.4).
  final Pitch? kan;

  /// Meend: glide from this note into the next.
  final bool glideToNext;

  /// A `,` phrase break comes before this note.
  final bool breakBefore;

  bool get isRest => pitch == null;
  Fraction get end => start + duration;

  Note copyWith({Fraction? duration, bool? glideToNext}) => Note(
    pitch: pitch,
    start: start,
    duration: duration ?? this.duration,
    kan: kan,
    glideToNext: glideToNext ?? this.glideToNext,
    breakBefore: breakBefore,
  );

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.pitch == pitch &&
      other.start == start &&
      other.duration == duration &&
      other.kan == kan &&
      other.glideToNext == glideToNext &&
      other.breakBefore == breakBefore;

  @override
  int get hashCode => Object.hash(pitch, start, duration, kan, glideToNext, breakBefore);

  @override
  String toString() =>
      '${breakBefore ? ', ' : ''}${kan == null ? '' : '{$kan}'}${pitch?.ascii ?? '_'}'
      '${glideToNext ? '~' : ''}@$start+$duration';
}

/// A `|` (vibhag) or `||` (end of avartan) bar, at a matra boundary.
class Bar {
  const Bar(this.at, {this.avartanEnd = false});
  final Fraction at;
  final bool avartanEnd;

  @override
  bool operator ==(Object other) =>
      other is Bar && other.at == at && other.avartanEnd == avartanEnd;

  @override
  int get hashCode => Object.hash(at, avartanEnd);

  @override
  String toString() => '${avartanEnd ? '||' : '|'}@$at';
}

/// Parsed notation (docs/03-notation.md). All pitches are relative to Sa.
class Phrase {
  const Phrase({required this.notes, this.bars = const [], this.header = const {}});

  final List<Note> notes;
  final List<Bar> bars;

  /// `key: value` lines from the notation header, in order.
  final Map<String, String> header;

  Taal? get taal => header['taal'] == null ? null : Taal.byId(header['taal']!);

  /// Matras per minute, if the header gives one.
  double? get tempo => double.tryParse(header['tempo'] ?? '');

  String? get title => header['title'];

  /// Played notes only, in order (rests left out).
  List<Note> get sounding => [
    for (final n in notes)
      if (!n.isRest) n,
  ];

  List<Pitch> get pitches => [for (final n in sounding) n.pitch!];

  /// Total length in matras, including trailing rests and bars.
  Fraction get length {
    var end = Fraction.zero;
    for (final n in notes) {
      if (n.end > end) end = n.end;
    }
    for (final b in bars) {
      if (b.at > end) end = b.at;
    }
    return end;
  }

  @override
  bool operator ==(Object other) =>
      other is Phrase &&
      _listEquals(other.notes, notes) &&
      _listEquals(other.bars, bars) &&
      _mapEquals(other.header, header);

  @override
  int get hashCode => Object.hash(Object.hashAll(notes), Object.hashAll(bars), header.length);

  @override
  String toString() => 'Phrase(${notes.join(' ')})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (a[k] != b[k]) return false;
  }
  return true;
}
