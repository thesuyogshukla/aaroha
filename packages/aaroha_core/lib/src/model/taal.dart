/// Taals with their vibhag (section) lengths in matras.
enum Taal {
  teentaal('teentaal', [4, 4, 4, 4]),
  keherwa('keherwa', [4, 4]),
  dadra('dadra', [3, 3]),
  rupak('rupak', [3, 2, 2]),
  jhaptaal('jhaptaal', [2, 3, 2, 3]),
  ektaal('ektaal', [2, 2, 2, 2, 2, 2]);

  const Taal(this.id, this.vibhags);

  /// Name as written in notation headers (`taal: teentaal`).
  final String id;
  final List<int> vibhags;

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
