import 'dart:math' as math;

import '../model/swar.dart';
import '../model/tuning.dart';
import 'judge.dart';
import 'pitch_frame.dart';
import 'segmenter.dart';

/// One point of the player's pitch curve.
class TracePoint {
  const TracePoint(this.seconds, this.cents);

  /// From the start of the trace.
  final double seconds;

  /// From Sa.
  final double cents;
}

/// A played note on the trace, with its verdict.
class TraceNote {
  const TraceNote({required this.start, required this.end, required this.judged});

  final double start;
  final double end;
  final JudgedNote judged;
}

/// The player's pitch over one attempt, drawn against the target swars after
/// the verdict (docs/05 §10). Never shown while playing.
class PitchTrace {
  const PitchTrace({
    required this.lines,
    required this.notes,
    required this.lanes,
    required this.duration,
    required this.low,
    required this.high,
  });

  /// Stretches of voiced pitch; a gap in the playing breaks the line.
  final List<List<TracePoint>> lines;

  /// Played notes with their verdicts (extra notes included).
  final List<TraceNote> notes;

  /// The target swars, each with its cents in the session's tuning, low to
  /// high, without repeats.
  final List<({Pitch pitch, double cents})> lanes;

  final double duration;

  /// Cents range to draw.
  final double low;
  final double high;

  bool get isEmpty => lines.isEmpty;

  /// The note under [seconds], if any.
  TraceNote? noteAt(double seconds) {
    for (final n in notes) {
      if (seconds >= n.start && seconds <= n.end) return n;
    }
    return null;
  }
}

/// Builds the trace of one attempt from the frames heard while listening.
/// The curve starts [padSeconds] before the first voiced frame and ends
/// [padSeconds] after the last.
PitchTrace buildPitchTrace(
  List<PitchFrame> frames,
  AttemptResult result,
  List<Pitch> target, {
  required double saHz,
  Tuning tuning = Tuning.equal,
  SegmenterConfig config = const SegmenterConfig(),
  double padSeconds = 0.2,
  double minSpan = 400,
}) {
  final lanes = <({Pitch pitch, double cents})>[
    for (final p in {...target}) (pitch: p, cents: tuning.centsOf(p)),
  ]..sort((a, b) => a.cents.compareTo(b.cents));
  final cents = cleanCents(frames, saHz, config);
  final voiced = [
    for (var i = 0; i < frames.length; i++)
      if (cents[i] != null) i,
  ];
  if (voiced.isEmpty) {
    final c = lanes.map((l) => l.cents);
    return PitchTrace(
      lines: const [],
      notes: const [],
      lanes: lanes,
      duration: 0,
      low: (c.reduce(math.min) + c.reduce(math.max)) / 2 - minSpan / 2,
      high: (c.reduce(math.min) + c.reduce(math.max)) / 2 + minSpan / 2,
    );
  }
  final sr = config.sampleRate;
  final origin = frames[voiced.first].time - padSeconds * sr;
  double at(int time) => (time - origin) / sr;

  final notes = [
    for (final n in result.notes)
      if (n.played != null)
        TraceNote(start: at(n.played!.onset), end: at(n.played!.end), judged: n),
  ];
  bool inNote(int i) => result.notes.any(
    (n) => n.played != null && frames[i].time >= n.played!.onset && frames[i].time < n.played!.end,
  );

  // The range covers the target swars and the judged notes, at least
  // [minSpan] cents so a single note's wobble isn't blown up. Stray frames
  // between notes don't stretch it.
  final ranged = [
    for (final l in lanes) l.cents,
    for (final i in voiced)
      if (inNote(i)) cents[i]!,
  ];
  var low = ranged.reduce(math.min) - 60, high = ranged.reduce(math.max) + 60;
  if (high - low < minSpan) {
    final mid = (high + low) / 2;
    low = mid - minSpan / 2;
    high = mid + minSpan / 2;
  }

  // A line breaks where the playing stops for more than a couple of frames,
  // and around stray frames outside the range.
  final lines = <List<TracePoint>>[];
  int? previous;
  for (final i in voiced) {
    final c = cents[i]!;
    if (c < low || c > high) {
      previous = null;
      continue;
    }
    if (previous == null || i - previous > 3) lines.add([]);
    lines.last.add(TracePoint(at(frames[i].time), c));
    previous = i;
  }

  return PitchTrace(
    lines: lines,
    notes: notes,
    lanes: lanes,
    duration: at(frames[voiced.last].time) + padSeconds,
    low: low,
    high: high,
  );
}
