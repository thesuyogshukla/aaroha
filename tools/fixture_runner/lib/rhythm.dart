import 'dart:math' as math;
import 'dart:typed_data';

import 'package:aaroha_core/aaroha_core.dart';

import 'synth.dart';

/// How well detected notes line up with a rhythm take's written timing
/// (docs/08 M3-D): played to the metronome from sam, the sound reaching the
/// mic a sound delay after each click.
///
/// Two things are mixed in "detected minus written": the player's timing and
/// the detector's. [fit] separates the player's steady drift (rushing or
/// dragging); [detectorMs] compares each onset with where the note's own
/// pitch rises in the audio, which the player's timing doesn't affect.
class OnsetReport {
  OnsetReport({
    required this.expected,
    required this.detected,
    required this.errorsMs,
    required this.matraMs,
    this.detectorMs = const [],
    this.fit,
  });

  final int expected;
  final int detected;

  /// Detected minus written onset of each matched note, in milliseconds.
  final List<double> errorsMs;
  final double matraMs;

  /// Detected onset minus [pitchRiseOnset], per matched note. Empty when no
  /// audio was given.
  final List<double> detectorMs;

  /// The player's tempo against the click, from the matched onsets.
  final TempoFit? fit;

  int get matched => errorsMs.length;
  int get extra => detected - matched;

  static double _quantile(List<double> v, double q) {
    if (v.isEmpty) return double.nan;
    final s = [...v]..sort();
    return s[((s.length - 1) * q).round()];
  }

  double get medianAbsMs => _quantile([for (final e in errorsMs) e.abs()], 0.5);
  double get biasMs => _quantile(errorsMs, 0.5);
  double get worstMs =>
      errorsMs.isEmpty ? double.nan : errorsMs.map((e) => e.abs()).reduce(math.max);

  /// Median and 90th percentile of |[detectorMs]|.
  double get detectorMedianMs => _quantile([for (final e in detectorMs) e.abs()], 0.5);
  double get detectorP90Ms => _quantile([for (final e in detectorMs) e.abs()], 0.9);

  String _ms(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}';

  @override
  String toString() {
    final lines = [
      '$matched/$expected notes matched ($detected detected); onset error median '
          '${medianAbsMs.toStringAsFixed(0)} ms (${(100 * medianAbsMs / matraMs).toStringAsFixed(0)}% '
          'of a matra), bias ${_ms(biasMs)} ms, worst ${worstMs.toStringAsFixed(0)} ms',
      if (fit != null)
        '    player: ${fit!.driftLabel}, first note ${_ms(fit!.offset)} ms, notes within '
            '${fit!.scatter.toStringAsFixed(0)} ms (median) of that line',
      if (detectorMs.isNotEmpty)
        '    detector against the pitch rise: median ${detectorMedianMs.toStringAsFixed(0)} ms, '
            '90% within ${detectorP90Ms.toStringAsFixed(0)} ms, bias '
            '${_ms(_quantile(detectorMs, 0.5))} ms',
    ];
    return lines.join('\n');
  }
}

/// Matches [notes] to [phrase]'s written notes and measures each onset.
/// A note within [toleranceCents] of a written swar counts as it: rhythm
/// takes are about timing, so a sharp Ma is still the Ma.
///
/// With [samples], each matched onset is also compared with
/// [pitchRiseOnset].
OnsetReport scoreOnsets(
  List<DetectedNote> notes,
  Phrase phrase, {
  required int samFrame,
  required double matraFrames,
  required int delayFrames,
  required int sampleRate,
  Tuning tuning = Tuning.equal,
  double toleranceCents = 60,
  Float32List? samples,
  double? saHz,
}) {
  final sounding = phrase.sounding;
  final expectedAt = [
    for (final n in sounding) samFrame + delayFrames + (n.start.toDouble() * matraFrames).round(),
  ];
  final pairs = alignNotes(
    [for (final n in sounding) tuning.centsOf(n.pitch!)],
    [for (final n in notes) n.cents],
    toleranceCents: toleranceCents,
  );
  double ms(int frames) => 1000 * frames / sampleRate;
  return OnsetReport(
    expected: sounding.length,
    detected: notes.length,
    errorsMs: [for (final (e, d) in pairs) ms(notes[d].onset - expectedAt[e])],
    matraMs: 1000 * matraFrames / sampleRate,
    detectorMs: samples == null || saHz == null
        ? const []
        : [
            for (final (_, d) in pairs)
              ms(notes[d].onset - pitchRiseOnset(samples, sampleRate, notes[d], saHz)),
          ],
    fit: TempoFit.of(
      [for (final (e, _) in pairs) ms(expectedAt[e])],
      [for (final (_, d) in pairs) ms(notes[d].onset)],
    ),
  );
}

/// Longest common subsequence of written and detected notes (cents from Sa),
/// a pair matching when they are within [toleranceCents], as index pairs.
List<(int, int)> alignNotes(
  List<double> expected,
  List<double> detected, {
  double toleranceCents = 60,
}) {
  bool same(int i, int j) => (expected[i] - detected[j]).abs() <= toleranceCents;
  final n = expected.length, m = detected.length;
  final table = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      // Not plain LCS: matching within a tolerance isn't transitive, so
      // taking a match isn't always best.
      table[i][j] = math.max(
        same(i, j) ? table[i + 1][j + 1] + 1 : 0,
        math.max(table[i + 1][j], table[i][j + 1]),
      );
    }
  }
  final out = <(int, int)>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (same(i, j) && table[i][j] == table[i + 1][j + 1] + 1) {
      out.add((i, j));
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return out;
}

/// Where [note] starts in [samples], from the energy at its own pitch rather
/// than from pitch tracking: an independent check on the segmenter's onsets.
///
/// The energy is measured at the note's fundamental (10 ms Hann window,
/// every 2.5 ms). Walking back from the segmenter's onset, at most 250 ms,
/// to the lowest point before the note, the onset is the first moment after
/// it within 12 dB of the note's loudest in its first 100 ms. Metronome
/// clicks are noise spread over 1–4 kHz, so they hardly register at a
/// flute's fundamental; an energy or spectral-flux detector over the whole
/// band locks onto them instead (decisions.md D52).
int pitchRiseOnset(Float32List samples, int sampleRate, DetectedNote note, double saHz) {
  final hop = sampleRate * 25 ~/ 10000;
  final window = sampleRate ~/ 100;
  final f0 = saHz * math.pow(2, note.cents / 1200);
  final coeff = 2 * math.cos(2 * math.pi * f0 / sampleRate);
  double db(int centre) {
    final a = centre - window ~/ 2;
    if (a < 0 || a + window >= samples.length) return -200;
    var s1 = 0.0, s2 = 0.0;
    for (var j = 0; j < window; j++) {
      final w = 0.5 - 0.5 * math.cos(2 * math.pi * j / window);
      final s0 = samples[a + j] * w + coeff * s1 - s2;
      s2 = s1;
      s1 = s0;
    }
    final power = math.max(0.0, s1 * s1 + s2 * s2 - coeff * s1 * s2);
    return 10 * math.log(power + 1e-18) / math.ln10;
  }

  final onset = note.onset;
  var level = -200.0;
  for (var t = onset; t < onset + sampleRate ~/ 10; t += hop) {
    level = math.max(level, db(t));
  }
  final target = level - 12;
  var lowest = db(onset), low = onset;
  for (var t = onset - hop; t > onset - sampleRate ~/ 4; t -= hop) {
    final v = db(t);
    if (v < lowest) {
      lowest = v;
      low = t;
    }
    if (v < target - 12) break;
  }
  var t = low;
  while (t < onset + sampleRate ~/ 10 && db(t) < target) {
    t += hop;
  }
  return t;
}

/// [phrase] as synthetic flute notes at [tempo], each released [gapMs]
/// before the next note or rest, starting 100 ms in (where [synthesize]
/// starts). Returns the audio and the frame where matra 0 falls.
({SynthResult synth, int samFrame}) synthesizeRhythm(
  Phrase phrase,
  double saHz,
  int sampleRate, {
  required int tempo,
  int gapMs = 50,
}) {
  final matraMs = 60000 / tempo;
  final sounding = phrase.sounding;
  final notes = <SynthNote>[];
  for (var i = 0; i < sounding.length; i++) {
    final n = sounding[i];
    final next = i + 1 < sounding.length ? sounding[i + 1].start : phrase.length;
    // From whole-phrase positions, so rounding doesn't add up note by note.
    final slotMs = (next.toDouble() * matraMs).round() - (n.start.toDouble() * matraMs).round();
    final soundMs = (n.duration.toDouble() * matraMs).round() - gapMs;
    notes.add(
      SynthNote(Tuning.just.centsOf(n.pitch!), durationMs: soundMs, gapMs: slotMs - soundMs),
    );
  }
  return (synth: synthesize(notes, saHz, sampleRate), samFrame: 100 * sampleRate ~/ 1000);
}
