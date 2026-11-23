import 'dart:math' as math;
import 'dart:typed_data';

/// How long the app's sound takes to come back through the mic, measured
/// from clicks the app played (docs/08 M3-C).
class LatencyMeasurement {
  const LatencyMeasurement({
    required this.ms,
    required this.spreadMs,
    required this.each,
    required this.played,
  });

  /// Median delay from when a click was scheduled to when it reached the mic.
  final double ms;

  /// Largest minus smallest of the clicks that were heard.
  final double spreadMs;

  /// Each heard click's delay, in the order played.
  final List<double> each;
  final int played;

  int get heard => each.length;

  /// Enough clicks were heard, and they agree.
  bool get ok => heard >= math.max(3, played - 1) && spreadMs <= maxSpreadMs;

  /// Clicks that disagree by more than this make the measurement unusable.
  static const maxSpreadMs = 5.0;

  @override
  String toString() =>
      '${ms.toStringAsFixed(1)} ms (±${(spreadMs / 2).toStringAsFixed(1)}, $heard/$played heard)';
}

/// Finds where the clicks scheduled at [clickFrames] (sample positions in
/// [samples]) arrived in a recording of the mic, and how late.
///
/// Each click's onset is the first sharp rise in high-frequency energy
/// (above 1 kHz, clear of the drone and room rumble) between [minMs] and
/// [maxMs] after it was played. Echoes off walls arrive later and quieter,
/// on top of the click's own sound, so they don't count as a new rise. The
/// delay most of the clicks agree on is kept, and each click's onset nearest
/// it. Clicks must be further apart than [maxMs]. Returns null when no click
/// was heard at all.
LatencyMeasurement? measureLatency(
  Float32List samples,
  int sampleRate,
  List<int> clickFrames, {
  double minMs = 5,
  double maxMs = 900,
}) {
  final onsets = _onsets(_highpass(samples, sampleRate, 1000), sampleRate);
  double ms(int frames) => 1000 * frames / sampleRate;

  // Every onset that could belong to each click, as a delay.
  final candidates = [
    for (final t in clickFrames)
      [
        for (final o in onsets)
          if (ms(o - t) >= minMs && ms(o - t) <= maxMs) ms(o - t),
      ],
  ];
  final all = candidates.expand((c) => c).toList();
  if (all.isEmpty) return null;

  // The delay the most clicks agree on, within 3 ms.
  var best = all.first, bestVotes = 0;
  for (final d in all) {
    final votes = candidates.where((c) => c.any((x) => (x - d).abs() <= 3)).length;
    if (votes > bestVotes) {
      best = d;
      bestVotes = votes;
    }
  }
  final each = <double>[];
  for (final c in candidates) {
    final near = c.where((x) => (x - best).abs() <= 10).toList();
    if (near.isEmpty) continue;
    near.sort((a, b) => (a - best).abs().compareTo((b - best).abs()));
    each.add(near.first);
  }
  final sorted = [...each]..sort();
  return LatencyMeasurement(
    ms: sorted[sorted.length ~/ 2],
    spreadMs: sorted.last - sorted.first,
    each: each,
    played: clickFrames.length,
  );
}

/// Second-order high-pass (RBJ), so low sounds can't mask a click's onset.
Float32List _highpass(Float32List x, int sampleRate, double hz) {
  final w0 = 2 * math.pi * hz / sampleRate;
  final alpha = math.sin(w0) / (2 * math.sqrt1_2);
  final cosw = math.cos(w0);
  final a0 = 1 + alpha;
  final b0 = (1 + cosw) / 2 / a0, b1 = -(1 + cosw) / a0, b2 = b0;
  final a1 = -2 * cosw / a0, a2 = (1 - alpha) / a0;
  final y = Float32List(x.length);
  var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
  for (var i = 0; i < x.length; i++) {
    final v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x[i];
    y2 = y1;
    y1 = v;
    y[i] = v;
  }
  return y;
}

/// Sample positions where the energy jumps: 1 ms energy more than 15 dB above
/// the loudest of the 50 ms before it and well above the recording's
/// background, reaching within 20 dB of the loudest moment in the recording
/// within 2 ms, at most one every 30 ms. Each is refined to the first sample
/// of the rise. A click that lands on another loud sound (a drone pluck) is
/// not a clean rise and is missed; the measurement silences the drone.
List<int> _onsets(Float32List x, int sampleRate) {
  final hop = math.max(1, sampleRate ~/ 1000);
  final n = x.length ~/ hop;
  if (n == 0) return const [];
  final energy = Float64List(n);
  for (var i = 0; i < n; i++) {
    var sum = 0.0;
    for (var k = i * hop; k < (i + 1) * hop; k++) {
      sum += x[k] * x[k];
    }
    energy[i] = sum / hop;
  }
  final background = ([...energy]..sort())[n ~/ 2];
  final floor = math.max(background * 30, 1e-9);
  // A click is among the loudest things in the recording; a quiet room
  // sound 30 dB down is not one, however sharply it starts.
  final loudest = energy.reduce(math.max);
  final out = <int>[];
  var last = -1000000;
  for (var i = 10; i < n; i++) {
    if (energy[i] < floor || i - last < 30) continue;
    // The 50 ms before, leaving out the 2 ms just before the rise.
    var before = 0.0;
    for (var k = math.max(0, i - 52); k < i - 2; k++) {
      before = math.max(before, energy[k]);
    }
    if (energy[i] < before * 30) continue;
    var soon = 0.0;
    for (var k = i; k < math.min(n, i + 2); k++) {
      soon = math.max(soon, energy[k]);
    }
    if (soon < loudest / 100) continue;
    // The first sample within the previous millisecond and this one that
    // reaches a quarter of this millisecond's peak.
    var peak = 0.0;
    for (var k = i * hop; k < (i + 1) * hop; k++) {
      peak = math.max(peak, x[k].abs());
    }
    var at = i * hop;
    for (var k = math.max(0, (i - 1) * hop); k < (i + 1) * hop; k++) {
      if (x[k].abs() >= 0.25 * peak) {
        at = k;
        break;
      }
    }
    out.add(at);
    last = i;
  }
  return out;
}
