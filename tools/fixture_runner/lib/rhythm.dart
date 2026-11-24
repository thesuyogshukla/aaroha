import 'dart:math' as math;

import 'package:aaroha_core/aaroha_core.dart';

import 'synth.dart';

/// How well detected notes line up with a rhythm take's written timing
/// (docs/08 M3-D): played to the metronome from [samFrame], the sound
/// reaching the mic [delayFrames] after each click.
class OnsetReport {
  OnsetReport({
    required this.expected,
    required this.detected,
    required this.errorsMs,
    required this.matraMs,
  });

  final int expected;
  final int detected;

  /// Detected minus expected onset of each matched note, in milliseconds.
  final List<double> errorsMs;
  final double matraMs;

  int get matched => errorsMs.length;

  double _median(List<double> v) {
    if (v.isEmpty) return double.nan;
    final s = [...v]..sort();
    return s[s.length ~/ 2];
  }

  double get medianAbsMs => _median([for (final e in errorsMs) e.abs()]);
  double get biasMs => _median(errorsMs);
  double get worstMs =>
      errorsMs.isEmpty ? double.nan : errorsMs.map((e) => e.abs()).reduce(math.max);

  @override
  String toString() =>
      '$matched/$expected notes matched ($detected detected); onset error median '
      '${medianAbsMs.toStringAsFixed(0)} ms (${(100 * medianAbsMs / matraMs).toStringAsFixed(0)}% '
      'of a matra), bias ${biasMs >= 0 ? '+' : ''}${biasMs.toStringAsFixed(0)} ms, worst '
      '${worstMs.toStringAsFixed(0)} ms';
}

OnsetReport scoreOnsets(
  List<DetectedNote> notes,
  Phrase phrase, {
  required int samFrame,
  required double matraFrames,
  required int delayFrames,
  required int sampleRate,
}) {
  final sounding = phrase.sounding;
  final expectedAt = [
    for (final n in sounding) samFrame + delayFrames + (n.start.toDouble() * matraFrames).round(),
  ];
  final pairs = alignPitches(
    [for (final n in sounding) n.pitch!],
    [for (final n in notes) n.pitch],
  );
  return OnsetReport(
    expected: sounding.length,
    detected: notes.length,
    errorsMs: [for (final (e, d) in pairs) 1000 * (notes[d].onset - expectedAt[e]) / sampleRate],
    matraMs: 1000 * matraFrames / sampleRate,
  );
}

/// Longest common subsequence of [expected] and [detected], as index pairs.
List<(int, int)> alignPitches(List<Pitch> expected, List<Pitch> detected) {
  final n = expected.length, m = detected.length;
  final table = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      table[i][j] = expected[i] == detected[j]
          ? table[i + 1][j + 1] + 1
          : math.max(table[i + 1][j], table[i][j + 1]);
    }
  }
  final out = <(int, int)>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (expected[i] == detected[j]) {
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
