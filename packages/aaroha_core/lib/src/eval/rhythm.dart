import 'dart:math' as math;

import '../model/phrase.dart';
import 'judge.dart';

/// Where a played note fell against its written place (docs/05 §5).
enum Timing { onTime, early, late }

/// The player's tempo over an attempt, against the click.
enum Drift { steady, rushing, dragging }

/// Defaults from docs/05 §5 (decisions.md D53).
class RhythmSettings {
  const RhythmSettings({
    this.tolerance = 0.15,
    this.minHoldMatras = 2,
    this.shortHold = 0.75,
    this.driftRatio = 0.05,
    this.minDriftNotes = 4,
    this.minDriftMatras = 3,
  });

  /// A note within this fraction of a matra of its written place is on time.
  final double tolerance;

  /// Only notes written this long or longer are checked for being held:
  /// a hold is a skill, while a shorter note may be played short by style.
  final double minHoldMatras;

  /// A hold that stops before this fraction of its written length (from
  /// its written start) is "held too short".
  final double shortHold;

  /// A tempo this much faster or slower than the click's, over the attempt,
  /// is rushing or dragging.
  final double driftRatio;

  /// Drift needs at least this many timed notes, spread over at least this
  /// many matras.
  final int minDriftNotes;
  final double minDriftMatras;
}

/// One target note's timing.
class NoteTiming {
  const NoteTiming({required this.offset, required this.timing, this.held, this.heldShort = false});

  /// Played minus written onset, in matras (negative: early).
  final double offset;
  final Timing timing;

  /// For a written hold: how far into its written length it was still
  /// sounding, from its written start (1: to the end). Null for shorter
  /// notes.
  final double? held;
  final bool heldShort;

  bool get good => timing == Timing.onTime && !heldShort;

  @override
  String toString() =>
      '${timing.name}(${offset >= 0 ? '+' : ''}${offset.toStringAsFixed(2)})'
      '${held == null ? '' : ' held ${held!.toStringAsFixed(2)}${heldShort ? ' short' : ''}'}';
}

/// How an attempt's timing compares with the written phrase.
class RhythmResult {
  const RhythmResult({
    required this.notes,
    required this.sam,
    required this.matraFrames,
    this.delayFrames = 0,
    this.entry = 0,
    this.drift,
    this.tempoRatio,
  });

  /// One entry per target note, in order; null where nothing was played for
  /// it.
  final List<NoteTiming?> notes;

  /// Where the phrase was timed from: the engine frame of the click the
  /// player came in on (a sam, or the phrase's place in the cycle, when they
  /// came in where they should; see [entry]).
  final int sam;

  /// How many matras from where the phrase should start the player came in
  /// (D58): 0 when right, 4 for a vibhag late in keherwa, -1 for a matra
  /// early. The notes are timed from where the player came in, so a wrong
  /// entry is said once instead of making every note early or late.
  final int entry;

  /// The grid the notes were timed on: engine frames per matra, and the
  /// sound delay.
  final double matraFrames;
  final int delayFrames;

  /// Where engine frame [frame], heard at the mic, falls on the phrase's
  /// written time line, in matras from its start.
  double matraAt(int frame) => (frame - sam - delayFrames) / matraFrames;

  /// Null when there were too few notes to tell.
  final Drift? drift;

  /// The player's tempo over the click's (above 1: faster).
  final double? tempoRatio;

  /// Came in where the phrase starts, every note played on time, and every
  /// hold held.
  bool get inTime => entry == 0 && notes.every((n) => n == null || n.good);

  int count(Timing t) => notes.where((n) => n?.timing == t).length;
  int get heldShort => notes.where((n) => n?.heldShort ?? false).length;

  @override
  String toString() =>
      '${inTime ? 'IN TIME' : 'OFF'} ${notes.join(' ')}${drift == null ? '' : ' ${drift!.name}'}';
}

/// Judges the timing of an attempt already judged for pitch (docs/05 §5).
///
/// [sams] are the engine frames of the sams the player could have started
/// on, as scheduled; the phrase is timed from whichever fits the played
/// notes best, so the player may come in on any of them. A note played in
/// time reaches the mic [delayFrames] after its click (the sound delay,
/// D45). Every target matched to a played note is timed, the right swar or
/// not. Returns null when there are no sams or nothing to time.
///
/// The player may come in on the wrong matra: right after the call instead
/// of waiting for sam, or a vibhag late (D58). The notes are timed from the
/// matra that puts the most of them on time, the first note's matra when
/// several do, and how far that is from where the phrase should start is
/// [RhythmResult.entry]. With [cycleMatras], coming in any number of whole avartans late
/// is still right.
RhythmResult? judgeRhythm(
  Phrase phrase,
  AttemptResult result, {
  required List<int> sams,
  required double matraFrames,
  int delayFrames = 0,
  int? cycleMatras,
  RhythmSettings settings = const RhythmSettings(),
}) {
  final written = phrase.sounding;
  final targets = result.targets;
  if (sams.isEmpty || targets.length != written.length) return null;
  final timed = [
    for (var i = 0; i < targets.length; i++)
      if (targets[i].played != null) i,
  ];
  if (timed.isEmpty) return null;

  double offset(int i, int sam) =>
      (targets[i].played!.onset - sam - delayFrames) / matraFrames - written[i].start.toDouble();
  // Every note's offset from the first place the phrase may start, then the
  // whole number of matras that fits them best.
  final s0 = sams.first;
  final raw = [for (final i in timed) offset(i, s0)];
  final expected = [for (final s in sams) ((s - s0) / matraFrames).round()];
  int entryOf(int k) {
    if (cycleMatras != null && cycleMatras > 0) {
      final d = (k - expected.first) % cycleMatras;
      return d * 2 > cycleMatras ? d - cycleMatras : d;
    }
    return expected.map((e) => k - e).reduce((a, b) => a.abs() <= b.abs() ? a : b);
  }

  // Where the first note says the player came in; another whole number of
  // matras wins only by putting more notes on time (a short hold or a
  // hurried note shouldn't move the entry).
  final kFirst = raw.first.round();
  final lo = raw.reduce(math.min).floor() - 1, hi = raw.reduce(math.max).ceil() + 1;
  var k = kFirst;
  ({int onTime, int away, double error})? best;
  for (var c = lo; c <= hi; c++) {
    final score = (
      onTime: raw.where((o) => (o - c).abs() <= settings.tolerance).length,
      away: (c - kFirst).abs(),
      error: raw.fold(0.0, (sum, o) => sum + (o - c).abs()),
    );
    final better =
        best == null ||
        score.onTime > best.onTime ||
        (score.onTime == best.onTime &&
            (score.away < best.away || (score.away == best.away && score.error < best.error)));
    if (better) {
      best = score;
      k = c;
    }
  }
  final sam = s0 + (k * matraFrames).round();

  final notes = List<NoteTiming?>.filled(targets.length, null);
  for (final i in timed) {
    final o = offset(i, sam);
    final played = targets[i].played!;
    final length = written[i].duration.toDouble();
    // Measured from the written start, so a late start isn't counted twice:
    // what matters is that the note lasts to where it should end.
    final held = length >= settings.minHoldMatras
        ? ((played.end - sam - delayFrames) / matraFrames - written[i].start.toDouble()) / length
        : null;
    notes[i] = NoteTiming(
      offset: o,
      timing: o < -settings.tolerance
          ? Timing.early
          : o > settings.tolerance
          ? Timing.late
          : Timing.onTime,
      held: held,
      heldShort: held != null && held < settings.shortHold,
    );
  }

  final span = written[timed.last].start.toDouble() - written[timed.first].start.toDouble();
  final fit = timed.length >= settings.minDriftNotes && span >= settings.minDriftMatras
      ? TempoFit.of(
          [for (final i in timed) written[i].start.toDouble()],
          [for (final i in timed) (targets[i].played!.onset - sam) / matraFrames],
        )
      : null;
  return RhythmResult(
    notes: notes,
    sam: sam,
    matraFrames: matraFrames,
    delayFrames: delayFrames,
    entry: entryOf(k),
    tempoRatio: fit?.tempoRatio,
    drift: fit == null
        ? null
        : fit.tempoRatio > 1 + settings.driftRatio
        ? Drift.rushing
        : fit.tempoRatio < 1 - settings.driftRatio
        ? Drift.dragging
        : Drift.steady,
  );
}

/// A straight line through (written, played) onsets (docs/05 §5, tempo
/// drift), both in the same unit. [tempoRatio] above 1 means the player's
/// beats were shorter than the written ones: rushing.
class TempoFit {
  const TempoFit({required this.tempoRatio, required this.offset, required this.scatter});

  /// Fits played = a + b × written. Null for fewer than 3 points or no
  /// spread.
  static TempoFit? of(List<double> written, List<double> played) {
    final n = written.length;
    if (n < 3 || played.length != n) return null;
    final mx = written.reduce((a, b) => a + b) / n;
    final my = played.reduce((a, b) => a + b) / n;
    var sxx = 0.0, sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += (written[i] - mx) * (written[i] - mx);
      sxy += (written[i] - mx) * (played[i] - my);
    }
    if (sxx == 0) return null;
    final b = sxy / sxx;
    final a = my - b * mx;
    final residuals = [for (var i = 0; i < n; i++) (played[i] - a - b * written[i]).abs()]..sort();
    return TempoFit(
      tempoRatio: 1 / b,
      offset: a + (b - 1) * written.first,
      scatter: residuals[(n - 1) ~/ 2],
    );
  }

  final double tempoRatio;

  /// Where the line puts the first point, against its written place.
  final double offset;

  /// Median distance of the points from the line.
  final double scatter;

  /// "steady", "rushing 3.2%" or "dragging 1.5%" (under 1%: steady).
  String get driftLabel {
    final pct = (tempoRatio - 1) * 100;
    return pct.abs() < 1
        ? 'steady tempo'
        : '${pct > 0 ? 'rushing' : 'dragging'} ${pct.abs().toStringAsFixed(1)}%';
  }
}
