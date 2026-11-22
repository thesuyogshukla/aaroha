import 'dart:math' as math;

/// How long phrases may be, growing as the player gets them right
/// (docs/05 §9). Level 1 is 2–4 notes; each level adds a note, up to 8.
class PhraseLevel {
  const PhraseLevel._();

  static const top = 5;

  /// The longest phrase at [level]: 4, 5, 6, 7, 8.
  static int maxNotes(int level) => level.clamp(1, top) + 3;

  /// The shortest generated phrase: 2 at level 1, then two under the longest.
  static int minNotes(int level) => level <= 1 ? 2 : maxNotes(level) - 2;
}

/// Moves the phrase level from first tries on phrase rounds: after [window]
/// rounds at a level, it goes up when at least [upAt] of the last [window]
/// were right first time, and down when [downAt] or fewer were.
class PhraseLevelTracker {
  PhraseLevelTracker({
    this.level = 1,
    List<bool> recent = const [],
    this.window = 10,
    this.upAt = 0.8,
    this.downAt = 0.4,
  }) : _recent = [...recent];

  int level;
  final int window;
  final double upAt;
  final double downAt;
  final List<bool> _recent;

  /// First tries at this level, oldest first (at most [window]).
  List<bool> get recent => List.unmodifiable(_recent);

  /// Records one phrase round's first try; returns the level change (−1, 0
  /// or +1).
  int add(bool firstTryPassed) {
    _recent.add(firstTryPassed);
    if (_recent.length > window) _recent.removeAt(0);
    if (_recent.length < window) return 0;
    final rate = _recent.where((p) => p).length / window;
    final before = level;
    if (rate >= upAt) level = math.min(PhraseLevel.top, level + 1);
    if (rate <= downAt) level = math.max(1, level - 1);
    if (level != before) _recent.clear();
    return level - before;
  }

  Map<String, Object> toJson() => {'level': level, 'recent': _recent};

  factory PhraseLevelTracker.fromJson(Map<String, dynamic> j) => PhraseLevelTracker(
    level: (j['level'] as int? ?? 1).clamp(1, PhraseLevel.top),
    recent: [for (final r in j['recent'] as List? ?? const []) r == true],
  );
}
