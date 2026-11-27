import '../eval/judge.dart';
import '../eval/rhythm.dart';
import '../model/swar.dart';
import '../model/tuning.dart';

/// One target note's first-try outcome from a past attempt (docs/05 §7).
class NoteOutcome {
  const NoteOutcome({
    required this.target,
    required this.verdict,
    required this.at,
    this.played,
    this.cents,
    this.fluteId,
    this.named = false,
    this.offset,
  });

  final Pitch target;
  final Verdict verdict;
  final DateTime at;

  /// What was played or tapped, when something was.
  final Pitch? played;

  /// Played cents from Sa, for flute attempts (intonation).
  final double? cents;
  final int? fluteId;

  /// From Listen & name rather than playing.
  final bool named;

  /// Rhythm practice: played minus written onset, in matras (docs/05 §5).
  final double? offset;

  /// The ear got it: the right swar, in tune or not.
  bool get rightSwar => verdict == Verdict.pass || verdict == Verdict.outOfTune;
}

/// How the player's timed notes have fallen against the click.
class TimingRecord {
  const TimingRecord({
    required this.count,
    required this.onTime,
    required this.early,
    required this.late,
    required this.medianOffset,
  });

  final int count;
  final int onTime;
  final int early;
  final int late;

  /// The middle offset, in matras: which way the player leans.
  final double medianOffset;

  double get onTimeShare => onTime / count;
}

class SwarRecord {
  const SwarRecord(this.tries, this.misses);
  final int tries;
  final int misses;

  double? get accuracy => tries == 0 ? null : (tries - misses) / tries;
}

/// First-try history across sessions and both answer modes. Ear stats are
/// pooled across flutes (hearing is relative to Sa); intonation is per flute.
/// Everything is computed over each swar's most recent [window] first tries.
class PracticeHistory {
  PracticeHistory([Iterable<NoteOutcome> outcomes = const [], this.window = 40, DateTime? now])
    : _now = now {
    for (final o in outcomes) {
      add(o);
    }
  }

  final int window;
  final DateTime? _now;
  final _byTarget = <Pitch, List<NoteOutcome>>{};

  DateTime get now => _now ?? DateTime.now();

  /// Adds an outcome, keeping each swar's list in time order.
  void add(NoteOutcome o) {
    final list = _byTarget.putIfAbsent(o.target, () => []);
    var i = list.length;
    while (i > 0 && list[i - 1].at.isAfter(o.at)) {
      i--;
    }
    list.insert(i, o);
  }

  Iterable<Pitch> get targets => _byTarget.keys;

  List<NoteOutcome> _recent(Pitch p) {
    final all = _byTarget[p] ?? const [];
    return all.length <= window ? all : all.sublist(all.length - window);
  }

  SwarRecord recordOf(Pitch p) {
    final recent = _recent(p);
    return SwarRecord(recent.length, recent.where((o) => !o.rightSwar).length);
  }

  DateTime? lastSeen(Pitch p) => _byTarget[p]?.last.at;

  /// How likely [p] is to be picked next (docs/05 §8): the smoothed miss rate
  /// over its recent first tries, plus a floor so well-known swars still come
  /// up, times up to ×2 for swars not practised in a week.
  double weight(Pitch p) {
    final r = recordOf(p);
    final missRate = (r.misses + 1) / (r.tries + 2);
    final last = lastSeen(p);
    final days = last == null ? 7.0 : now.difference(last).inMinutes / (60 * 24);
    final recency = 1 + (days / 7).clamp(0.0, 1.0);
    return (0.15 + missRate) * recency;
  }

  /// Recent wrong answers: (target, answered) → count. Wrong swars and wrong
  /// octaves; out-of-tune right swars are not confusions. Nor is a note 50 c
  /// or more off whose nearest allowed swar is still the target: a miss, but
  /// not heard as anything else.
  Map<(Pitch, Pitch), int> get confusions {
    final out = <(Pitch, Pitch), int>{};
    for (final p in _byTarget.keys) {
      for (final o in _recent(p)) {
        final played = o.played;
        if (played == null || played == p || o.rightSwar || o.verdict == Verdict.missing) {
          continue;
        }
        out.update((p, played), (c) => c + 1, ifAbsent: () => 1);
      }
    }
    return out;
  }

  /// Confused pairs with at least [minCount] recent confusions, most first.
  List<(Pitch, Pitch)> confusedPairs({int minCount = 2}) {
    final entries = confusions.entries.where((e) => e.value >= minCount).toList()
      ..sort((a, b) => b.value - a.value);
    return [for (final e in entries) e.key];
  }

  /// Timing over the most recent [last] timed first-try notes from rhythm
  /// practice, all swars together; null before any (docs/08 M3-E).
  TimingRecord? timing({int last = 200, RhythmSettings settings = const RhythmSettings()}) {
    final timed = [
      for (final list in _byTarget.values)
        for (final o in list)
          if (o.offset != null) o,
    ]..sort((a, b) => a.at.compareTo(b.at));
    if (timed.isEmpty) return null;
    final recent = timed.length <= last ? timed : timed.sublist(timed.length - last);
    final offsets = [for (final o in recent) o.offset!]..sort();
    final tol = settings.tolerance;
    return TimingRecord(
      count: offsets.length,
      onTime: offsets.where((o) => o.abs() <= tol).length,
      early: offsets.where((o) => o < -tol).length,
      late: offsets.where((o) => o > tol).length,
      medianOffset: offsets[offsets.length ~/ 2],
    );
  }

  /// Mean played-minus-target cents per swar, in [tuning], over recent flute
  /// attempts on the right swar.
  Map<Pitch, ({double mean, int count})> intonation(Tuning tuning, {int? fluteId}) {
    final out = <Pitch, ({double mean, int count})>{};
    for (final p in _byTarget.keys) {
      final devs = [
        for (final o in _recent(p))
          if (o.cents != null && o.rightSwar && (fluteId == null || o.fluteId == fluteId))
            o.cents! - tuning.centsOf(p),
      ];
      if (devs.isEmpty) continue;
      out[p] = (mean: devs.reduce((a, b) => a + b) / devs.length, count: devs.length);
    }
    return out;
  }
}
