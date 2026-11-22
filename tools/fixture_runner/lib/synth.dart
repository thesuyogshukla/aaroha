import 'dart:math' as math;
import 'dart:typed_data';

/// A synthetic bansuri-like note for self-tests: a near-sinusoidal tone with
/// weak harmonics, breath noise, a flat attack scoop and light vibrato.
class SynthNote {
  const SynthNote(this.cents, {this.durationMs = 600, this.gapMs = 80});

  /// Cents from Sa, including any deliberate detune.
  final double cents;
  final int durationMs;

  /// Silence after the note.
  final int gapMs;
}

class SynthResult {
  SynthResult(this.samples, this.spans);
  final Float32List samples;

  /// Start and end sample of each note.
  final List<(int, int)> spans;
}

SynthResult synthesize(List<SynthNote> notes, double saHz, int sampleRate, {int seed = 1}) {
  final rng = math.Random(seed);
  final total = notes.fold<int>(0, (n, note) => n + note.durationMs + note.gapMs) + 200;
  final out = Float32List(total * sampleRate ~/ 1000);
  final spans = <(int, int)>[];

  var at = 100 * sampleRate ~/ 1000;
  for (final note in notes) {
    final length = note.durationMs * sampleRate ~/ 1000;
    final hz = saHz * math.pow(2, note.cents / 1200);
    var phase = 0.0;
    var noise = 0.0;
    for (var i = 0; i < length; i++) {
      final t = i / sampleRate;
      final scoop = -40 * math.exp(-t / 0.03);
      final vibrato = t > 0.2 ? 4 * math.sin(2 * math.pi * 5 * t) : 0.0;
      phase += 2 * math.pi * hz * math.pow(2, (scoop + vibrato) / 1200) / sampleRate;
      final envelope = math.min(1.0, t / 0.04) * math.min(1.0, (length - i) / (0.05 * sampleRate));
      noise += 0.3 * ((rng.nextDouble() * 2 - 1) - noise);
      final tone = math.sin(phase) + 0.25 * math.sin(2 * phase) + 0.08 * math.sin(3 * phase);
      out[at + i] = (envelope * (0.25 * tone + 0.02 * noise)).toDouble();
    }
    spans.add((at, at + length));
    at += length + note.gapMs * sampleRate ~/ 1000;
  }
  return SynthResult(out, spans);
}

double rms(Float32List x) {
  var sum = 0.0;
  for (final v in x) {
    sum += v * v;
  }
  return math.sqrt(sum / x.length);
}

/// [signal] + [other] scaled so that its RMS is [levelDb] relative to [signal].
Float32List mix(Float32List signal, Float32List other, double levelDb) {
  final gain = rms(signal) / rms(other) * math.pow(10, levelDb / 20);
  return Float32List.fromList([
    for (var i = 0; i < signal.length; i++) signal[i] + gain * other[i % other.length],
  ]);
}
