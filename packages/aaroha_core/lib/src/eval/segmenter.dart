import 'dart:math' as math;

import '../model/swar.dart';
import '../model/tuning.dart';
import 'pitch_frame.dart';

/// Defaults from docs/05-evaluation.md. Times are in milliseconds.
class SegmenterConfig {
  const SegmenterConfig({
    this.sampleRate = 48000,
    this.hop = 480,
    this.minConfidence = 0.85,
    this.noiseFloor = 0,
    this.loudnessFactor = 3,
    this.medianWindow = 5,
    this.hysteresisCents = 15,
    this.minNoteMs = 120,
    this.unstableNoteMs = 250,
    this.unstableCents = 20,
    this.octaveFlipMs = 200,
    this.faintNoteRatio = 0.15,
    this.faintNoteConfidence = 0.9,
    this.attackMs = 80,
    this.releaseMs = 40,
    this.levelWindowMs = 300,
    this.dipRatio = 0.16,
    this.dipMs = 20,
    this.recoverRatio = 0.5,
    this.maxDipMs = 400,
    this.quietRatio = 0.4,
    this.gapMs = 40,
    this.loudGapMs = 150,
  });

  final int sampleRate;

  /// Samples between pitch frames; a larger step between frames is a gap.
  final int hop;
  final double minConfidence;

  /// RMS of silence; frames must be [loudnessFactor] times louder to count.
  final double noiseFloor;
  final double loudnessFactor;
  final int medianWindow;
  final double hysteresisCents;
  final double minNoteMs;

  /// Runs shorter than [unstableNoteMs] whose pitch wobbles by more than
  /// [unstableCents] (standard deviation) are transitions, not notes.
  final double unstableNoteMs;
  final double unstableCents;

  /// A run shorter than this on the same swar as a neighbouring note, but in
  /// another octave, with no re-articulation between them, is that note
  /// cracking at its start or end: it becomes part of the note.
  final double octaveFlipMs;

  /// A note whose median RMS is below [faintNoteRatio] × the median of all
  /// notes' levels (0.15 ≈ 16.5 dB quieter) and whose median confidence is
  /// below [faintNoteConfidence] is a breath between notes, not a played
  /// note: on a sound that faint and unclear the tracker can lock onto half
  /// the pitch (decisions.md D29). Faint but clear notes stay.
  final double faintNoteRatio;
  final double faintNoteConfidence;
  final double attackMs;
  final double releaseMs;

  /// Loudness is compared with the peak over this much recent playing, so
  /// slow fades and swells don't count as dips.
  final double levelWindowMs;

  /// A re-articulation while the pitch stays voiced: RMS falls below
  /// [dipRatio] × the recent peak (≈ −16 dB) for at least [dipMs], then comes
  /// back to [recoverRatio] × that peak. Breath pulsing (~10–12 dB) stays
  /// above the dip line; a dip that never recovers is the note's tail.
  final double dipRatio;
  final double dipMs;
  final double recoverRatio;

  /// A dip longer than this is taken as the player's new level.
  final double maxDipMs;

  /// Unvoiced frames below [quietRatio] × the recent peak count as quiet.
  final double quietRatio;

  /// A quiet unvoiced stretch at least this long ends a note: the player
  /// stopped or re-articulated.
  final double gapMs;

  /// An unvoiced stretch that stays loud (e.g. a drone pluck masking the
  /// flute) only ends a note after this long.
  final double loudGapMs;

  double get frameMs => 1000 * hop / sampleRate;
}

/// A note found in a stream of pitch frames.
class DetectedNote {
  const DetectedNote({
    required this.pitch,
    required this.onset,
    required this.end,
    required this.cents,
    required this.deviation,
    required this.stability,
  });

  final Pitch pitch;

  /// Engine frames of the first frame and one hop past the last frame.
  final int onset;
  final int end;

  /// Median cents from Sa over the stable part of the note.
  final double cents;

  /// [cents] minus the tuning's cents for [pitch].
  final double deviation;

  /// Standard deviation of cents over the stable part.
  final double stability;

  double durationMs(int sampleRate) => 1000 * (end - onset) / sampleRate;

  @override
  String toString() =>
      '${pitch.ascii} ${deviation >= 0 ? '+' : ''}${deviation.toStringAsFixed(1)}c '
      '(±${stability.toStringAsFixed(1)}) @$onset';
}

class _Run {
  _Run(this.pitch, this.articulated);
  final Pitch pitch;

  /// True when the run starts after silence, a gap or a loudness dip, i.e.
  /// the player re-articulated, rather than just moving to the next note.
  bool articulated;
  final List<int> frames = [];

  /// Frames inside a loudness dip: they extend the note but don't count
  /// towards its pitch.
  final List<int> tail = [];
}

/// Steps 1–3 of docs/05-evaluation.md: frame cleanup, quantising to swars
/// with hysteresis, and segmentation into notes.
List<DetectedNote> segmentNotes(
  List<PitchFrame> frames, {
  required double saHz,
  Tuning tuning = Tuning.equal,
  SegmenterConfig config = const SegmenterConfig(),
}) {
  final cents = _cleanCents(frames, saHz, config);

  // Quantise and split into runs.
  final runs = <_Run>[];
  _Run? current;
  Pitch? held;
  var breakPending = true;
  var quietFrames = 0;
  var loudFrames = 0;
  final recentRms = <double>[]; // voiced frames since the last break, newest last
  double? dipReference; // recent peak when the current dip began
  var dipFrames = 0;
  final levelFrames = (config.levelWindowMs / config.frameMs).ceil();
  final dipFramesNeeded = (config.dipMs / config.frameMs).ceil();
  final maxDipFrames = (config.maxDipMs / config.frameMs).ceil();
  final gapFramesNeeded = (config.gapMs / config.frameMs).ceil();
  final loudGapFramesNeeded = (config.loudGapMs / config.frameMs).ceil();

  double recentPeak() => recentRms.isEmpty ? 0 : recentRms.reduce(math.max);

  void endNote() {
    current = null;
    held = null;
    breakPending = true;
    recentRms.clear();
    dipReference = null;
    dipFrames = 0;
  }

  for (var i = 0; i < frames.length; i++) {
    final gap = i > 0 && frames[i].time - frames[i - 1].time > config.hop * 1.5;
    if (gap) endNote();

    final rms = frames[i].rms;
    final c = cents[i];
    if (c == null) {
      if (current == null || rms < config.quietRatio * recentPeak()) {
        quietFrames++;
      } else {
        loudFrames++;
      }
      if (quietFrames >= gapFramesNeeded || loudFrames >= loudGapFramesNeeded) endNote();
      continue;
    }
    quietFrames = 0;
    loudFrames = 0;

    // A deep loudness dip belongs to the current note's tail. If the level
    // comes back, the player re-articulated and the next note starts there.
    if (current != null) {
      final inDip = dipReference != null;
      final reference = dipReference ?? recentPeak();
      if (rms < config.dipRatio * reference || (inDip && rms < config.recoverRatio * reference)) {
        dipReference = reference;
        if (++dipFrames < maxDipFrames) {
          current!.tail.add(i);
          continue;
        }
        // A long dip is the new normal level, not an articulation.
        dipReference = null;
        dipFrames = 0;
        recentRms.clear();
      } else if (inDip) {
        if (dipFrames >= dipFramesNeeded) breakPending = true;
        dipReference = null;
        dipFrames = 0;
      }
    }

    final nearest = tuning.nearest(c).pitch;
    var pitch = held;
    if (pitch == null || breakPending) {
      pitch = nearest;
    } else if (nearest != pitch) {
      final toHeld = (c - tuning.centsOf(pitch)).abs();
      final toNearest = (c - tuning.centsOf(nearest)).abs();
      if (toHeld - toNearest > config.hysteresisCents) pitch = nearest;
    }
    held = pitch;

    var run = current;
    if (run == null || run.pitch != pitch || breakPending) {
      run = _Run(pitch, breakPending);
      runs.add(run);
      breakPending = false;
    }
    current = run;
    run.frames.add(i);
    recentRms.add(rms);
    if (recentRms.length > levelFrames) recentRms.removeAt(0);
  }

  // Drop transitions, then merge neighbours on the same pitch that were only
  // separated by a transition.
  final minFrames = (config.minNoteMs / config.frameMs).ceil();
  final unstableFrames = (config.unstableNoteMs / config.frameMs).ceil();
  bool isTransition(_Run run) =>
      run.frames.length < minFrames ||
      (run.frames.length < unstableFrames &&
          _stdDev([for (final i in run.frames) cents[i]!]) > config.unstableCents);
  final kept = <_Run>[];
  var carryBreak = false;
  for (final run in runs) {
    if (isTransition(run)) {
      carryBreak = carryBreak || run.articulated;
      continue;
    }
    run.articulated = run.articulated || carryBreak;
    carryBreak = false;
    if (kept.isNotEmpty && kept.last.pitch == run.pitch && !run.articulated) {
      kept.last.frames.addAll(run.frames);
      kept.last.tail.addAll(run.tail);
    } else {
      kept.add(run);
    }
  }

  // Absorb short octave flips into the note they belong to, preferring the
  // following note (a cracked attack) over the previous one (a release).
  final flipFrames = (config.octaveFlipMs / config.frameMs).ceil();
  bool flipOf(_Run flip, _Run note) =>
      flip.frames.length < flipFrames &&
      flip.pitch.swar == note.pitch.swar &&
      flip.pitch.octave != note.pitch.octave &&
      note.frames.length >= flipFrames;
  for (var i = 0; i < kept.length; i++) {
    final run = kept[i];
    final next = i + 1 < kept.length ? kept[i + 1] : null;
    final previous = i > 0 ? kept[i - 1] : null;
    if (next != null && !next.articulated && flipOf(run, next)) {
      next.tail.addAll(run.frames);
      next.tail.addAll(run.tail);
      next.articulated = run.articulated;
    } else if (previous != null && !run.articulated && flipOf(run, previous)) {
      previous.tail.addAll(run.frames);
      previous.tail.addAll(run.tail);
    } else {
      continue;
    }
    kept.removeAt(i--);
  }

  // Drop notes far fainter than the rest of the attempt.
  if (kept.length > 1) {
    double median(_Run run, double Function(PitchFrame) of) {
      final values = [for (final i in run.frames) of(frames[i])]..sort();
      return values[values.length ~/ 2];
    }

    final levels = [for (final run in kept) median(run, (f) => f.rms)];
    final typical = ([...levels]..sort())[levels.length ~/ 2];
    for (var i = kept.length - 1; i >= 0; i--) {
      final faint = levels[i] < config.faintNoteRatio * typical;
      if (faint && median(kept[i], (f) => f.confidence) < config.faintNoteConfidence) {
        kept.removeAt(i);
      }
    }
  }

  return [for (final run in kept) _toNote(run, frames, cents, tuning, config)];
}

List<double?> _cleanCents(List<PitchFrame> frames, double saHz, SegmenterConfig config) {
  final minRms = config.noiseFloor * config.loudnessFactor;
  final raw = <double?>[
    for (final f in frames)
      f.hz > 0 && f.confidence >= config.minConfidence && f.rms >= minRms
          ? centsFromSa(f.hz, saHz)
          : null,
  ];

  // Median over voiced neighbours.
  final half = config.medianWindow ~/ 2;
  final smoothed = List<double?>.filled(raw.length, null);
  for (var i = 0; i < raw.length; i++) {
    if (raw[i] == null) continue;
    final window = <double>[
      for (var j = math.max(0, i - half); j <= math.min(raw.length - 1, i + half); j++) ?raw[j],
    ]..sort();
    smoothed[i] = window[window.length ~/ 2];
  }

  // Fold single-frame octave jumps back to their neighbours' octave.
  for (var i = 1; i < smoothed.length - 1; i++) {
    final c = smoothed[i], before = smoothed[i - 1], after = smoothed[i + 1];
    if (c == null || before == null || after == null) continue;
    bool octaveOff(double other) => ((c - other).abs() - 1200).abs() <= 50;
    if (octaveOff(before) && octaveOff(after) && (before - after).abs() < 50) {
      smoothed[i] = c + 1200 * ((before - c) / 1200).round();
    }
  }
  return smoothed;
}

DetectedNote _toNote(
  _Run run,
  List<PitchFrame> frames,
  List<double?> cents,
  Tuning tuning,
  SegmenterConfig config,
) {
  final first = run.tail.isEmpty
      ? run.frames.first
      : math.min(run.frames.first, run.tail.reduce(math.min));
  final last = run.tail.isEmpty
      ? run.frames.last
      : math.max(run.frames.last, run.tail.reduce(math.max));
  final onset = frames[first].time;
  final end = frames[last].time + config.hop;
  final attackEnd = onset + config.attackMs * config.sampleRate / 1000;
  final releaseStart = end - config.releaseMs * config.sampleRate / 1000;

  var stable = <double>[
    for (final i in run.frames)
      if (frames[i].time >= attackEnd && frames[i].time <= releaseStart) cents[i]!,
  ];
  if (stable.length < 3) stable = [for (final i in run.frames) cents[i]!];
  stable.sort();
  final median = stable[stable.length ~/ 2];

  return DetectedNote(
    pitch: run.pitch,
    onset: onset,
    end: end,
    cents: median,
    deviation: median - tuning.centsOf(run.pitch),
    stability: _stdDev(stable),
  );
}

double _stdDev(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
  return math.sqrt(variance);
}
