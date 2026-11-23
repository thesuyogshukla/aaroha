import '../model/fraction.dart';
import '../model/phrase.dart';
import '../model/swar.dart';

/// What sits at one position inside a matra (docs/03-notation.md).
enum CellKind {
  /// A note starts here.
  note,

  /// The note before carries on (`-`, Bhatkhande avagraha ऽ).
  hold,

  /// Silence (`_`).
  rest,
}

class NotationCell {
  const NotationCell(this.kind, {this.note, this.pitch, this.kan, this.glide = false});

  final CellKind kind;

  /// For a note or a hold: the note's index among the phrase's sounding
  /// notes (the same order as [Phrase.pitches]).
  final int? note;
  final Pitch? pitch;
  final Pitch? kan;

  /// A meend leaves the note at the end of this position.
  final bool glide;

  @override
  bool operator ==(Object other) =>
      other is NotationCell &&
      other.kind == kind &&
      other.note == note &&
      other.pitch == pitch &&
      other.kan == kan &&
      other.glide == glide;

  @override
  int get hashCode => Object.hash(kind, note, pitch, kan, glide);

  @override
  String toString() => switch (kind) {
    CellKind.note => '${kan == null ? '' : '{${kan!.ascii}}'}${pitch!.ascii}${glide ? '~' : ''}',
    CellKind.hold => '-${glide ? '~' : ''}',
    CellKind.rest => '_',
  };
}

/// One item of notation in reading order: a matra, a bar or a phrase break.
sealed class NotationItem {
  const NotationItem();
}

/// One matra: its positions, each an equal share of the matra.
class MatraItem extends NotationItem {
  const MatraItem(this.cells);
  final List<NotationCell> cells;

  @override
  String toString() => cells.join();
}

class BarItem extends NotationItem {
  const BarItem({this.avartanEnd = false});
  final bool avartanEnd;

  @override
  String toString() => avartanEnd ? '||' : '|';
}

class BreakItem extends NotationItem {
  const BreakItem();

  @override
  String toString() => ',';
}

/// [phrase] laid out matra by matra, with the fewest equal positions per
/// matra that place every note boundary. The printer writes it as text and
/// the app draws it (holds, arcs under shared matras, bars).
List<NotationItem> layoutNotation(Phrase phrase) {
  final out = <NotationItem>[];
  final sounding = phrase.sounding;
  final matras = _ceil(phrase.length);
  for (var m = 0; m <= matras; m++) {
    final at = Fraction(m);
    for (final b in phrase.bars.where((b) => b.at == at)) {
      out.add(BarItem(avartanEnd: b.avartanEnd));
    }
    if (m == matras) break;
    final inMatra = [
      for (final n in phrase.notes)
        if (n.start < at + Fraction.one && n.end > at) n,
    ];
    if (inMatra.isNotEmpty && inMatra.first.start == at && inMatra.first.breakBefore) {
      out.add(const BreakItem());
    }
    out.add(MatraItem(_cells(at, inMatra, sounding)));
  }
  return out;
}

List<NotationCell> _cells(Fraction at, List<Note> notes, List<Note> sounding) {
  // Enough equal positions to place every note boundary inside the matra.
  var positions = 1;
  for (final n in notes) {
    for (final t in [n.start, n.end]) {
      if (t > at && t < at + Fraction.one) positions = lcm(positions, (t - at).denominator);
    }
  }
  final cells = <NotationCell>[];
  for (var j = 0; j < positions; j++) {
    final t = at + Fraction(j, positions);
    final note = notes.where((n) => n.start <= t && n.end > t).firstOrNull;
    final next = at + Fraction(j + 1, positions);
    final glide = note != null && note.glideToNext && note.end == next;
    if (note == null || note.isRest) {
      cells.add(const NotationCell(CellKind.rest));
    } else if (note.start == t) {
      cells.add(
        NotationCell(
          CellKind.note,
          note: sounding.indexOf(note),
          pitch: note.pitch,
          kan: note.kan,
          glide: glide,
        ),
      );
    } else {
      cells.add(NotationCell(CellKind.hold, note: sounding.indexOf(note), glide: glide));
    }
  }
  return cells;
}

int _ceil(Fraction f) => f.isInteger ? f.numerator : f.floor() + 1;
