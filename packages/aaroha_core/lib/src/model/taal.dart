/// How a matra is marked in a taal: sam (the first matra), tali (a clap at
/// the start of a vibhag), khali (a wave: an empty vibhag) or none.
enum Beat { sam, tali, khali, plain }

/// Taals with their vibhag (section) lengths in matras, and which vibhags
/// are khali (by index).
enum Taal {
  teentaal('teentaal', 'Teentaal', [4, 4, 4, 4], [2]),
  keherwa('keherwa', 'Keherwa', [4, 4], [1]),
  dadra('dadra', 'Dadra', [3, 3], [1]),
  // Rupak starts on khali: its sam is a wave, not a clap.
  rupak('rupak', 'Rupak', [3, 2, 2], [0]),
  jhaptaal('jhaptaal', 'Jhaptaal', [2, 3, 2, 3], [2]),
  ektaal('ektaal', 'Ektaal', [2, 2, 2, 2, 2, 2], [1, 3]);

  const Taal(this.id, this.label, this.vibhags, this.khali);

  /// Name as written in notation headers (`taal: teentaal`).
  final String id;
  final String label;
  final List<int> vibhags;
  final List<int> khali;

  /// How [matra] (from a sam, any number of avartans on) is marked.
  Beat beatAt(int matra) {
    final at = matra % matras;
    var start = 0;
    for (var v = 0; v < vibhags.length; v++) {
      if (at == start) {
        if (khali.contains(v)) return Beat.khali;
        return v == 0 ? Beat.sam : Beat.tali;
      }
      start += vibhags[v];
    }
    return Beat.plain;
  }

  /// The vibhag lengths written out, as "4+4" or "3+2+2".
  String get shape => vibhags.join('+');

  int get matras => vibhags.fold(0, (a, b) => a + b);

  /// Matra offsets within an avartan where vibhag bars fall, excluding 0.
  List<int> get barOffsets {
    final out = <int>[];
    var at = 0;
    for (final v in vibhags.take(vibhags.length - 1)) {
      at += v;
      out.add(at);
    }
    return out;
  }

  static Taal? byId(String id) {
    for (final t in values) {
      if (t.id == id.trim().toLowerCase()) return t;
    }
    return null;
  }
}
