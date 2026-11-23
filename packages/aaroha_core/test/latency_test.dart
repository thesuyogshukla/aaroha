import 'dart:math' as math;
import 'dart:typed_data';

import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

const sr = 48000;

/// A room recording of clicks played at [times]: each a short noise burst,
/// [delayMs] late, with an echo, a low hum and background noise.
Float32List room(
  List<int> times, {
  required double delayMs,
  double noise = 0.002,
  double hum = 0.2,
  Set<int> missing = const {},
  int seed = 7,
}) {
  final rng = math.Random(seed);
  final out = Float32List(times.last + 2 * sr);
  for (var i = 0; i < out.length; i++) {
    out[i] = noise * (rng.nextDouble() * 2 - 1) + hum * math.sin(2 * math.pi * 98 * i / sr);
  }
  void burst(int at, double level) {
    for (var k = 0; k < (0.04 * sr).round() && at + k < out.length; k++) {
      final env = math.exp(-k / (0.008 * sr));
      out[at + k] += level * env * (rng.nextDouble() * 2 - 1);
    }
  }

  for (var c = 0; c < times.length; c++) {
    if (missing.contains(c)) continue;
    final at = times[c] + (delayMs * sr / 1000).round();
    burst(at, 0.3);
    burst(at + (0.006 * sr).round(), 0.12); // a wall
    burst(at + (0.023 * sr).round(), 0.06); // another
  }
  return out;
}

void main() {
  final times = [for (var k = 0; k < 6; k++) (0.3 * sr).round() + k * sr];

  test('finds the delay of clicks through a room, to a millisecond', () {
    for (final delay in [12.0, 180.5, 437.3, 612.0]) {
      final m = measureLatency(room(times, delayMs: delay), sr, times)!;
      expect(m.ms, closeTo(delay, 1), reason: '$delay ms');
      expect(m.heard, 6);
      expect(m.spreadMs, lessThan(1));
      expect(m.ok, isTrue);
    }
  });

  test('a click lost in the noise still measures; too few do not', () {
    final one = measureLatency(room(times, delayMs: 437.3, missing: {2}), sr, times)!;
    expect(one.ms, closeTo(437.3, 1));
    expect(one.heard, 5);
    expect(one.ok, isTrue);
    final half = measureLatency(room(times, delayMs: 437.3, missing: {0, 2, 4}), sr, times)!;
    expect(half.ok, isFalse, reason: 'three of six is not enough');
  });

  test('silence or noise alone gives nothing', () {
    final quiet = Float32List(5 * sr);
    expect(measureLatency(quiet, sr, times), isNull);
    final rng = math.Random(3);
    final noise = Float32List.fromList([
      for (var i = 0; i < 7 * sr; i++) 0.05 * (rng.nextDouble() * 2 - 1),
    ]);
    final m = measureLatency(noise, sr, times);
    expect(m == null || !m.ok, isTrue);
  });

  test('a stray tap is outvoted by the clicks', () {
    final audio = room(times, delayMs: 300);
    // A knock between clicks 1 and 2.
    for (var k = 0; k < 2000; k++) {
      audio[times[1] + (0.45 * sr).round() + k] += 0.5 * math.exp(-k / 300) * (k.isEven ? 1 : -1);
    }
    final m = measureLatency(audio, sr, times)!;
    expect(m.ms, closeTo(300, 1));
    expect(m.ok, isTrue);
  });

  test('WAV bytes decode: float and 16-bit', () {
    Uint8List wav(int format, int bits, List<double> samples) {
      final bytesPer = bits ~/ 8;
      final data = ByteData(44 + samples.length * bytesPer);
      void tag(int at, String s) {
        for (var i = 0; i < 4; i++) {
          data.setUint8(at + i, s.codeUnitAt(i));
        }
      }

      tag(0, 'RIFF');
      data.setUint32(4, 36 + samples.length * bytesPer, Endian.little);
      tag(8, 'WAVE');
      tag(12, 'fmt ');
      data.setUint32(16, 16, Endian.little);
      data.setUint16(20, format, Endian.little);
      data.setUint16(22, 1, Endian.little);
      data.setUint32(24, sr, Endian.little);
      data.setUint32(28, sr * bytesPer, Endian.little);
      data.setUint16(32, bytesPer, Endian.little);
      data.setUint16(34, bits, Endian.little);
      tag(36, 'data');
      data.setUint32(40, samples.length * bytesPer, Endian.little);
      for (var i = 0; i < samples.length; i++) {
        if (format == 3) {
          data.setFloat32(44 + 4 * i, samples[i], Endian.little);
        } else {
          data.setInt16(44 + 2 * i, (samples[i] * 32767).round(), Endian.little);
        }
      }
      return data.buffer.asUint8List();
    }

    final f = decodeWav(wav(3, 32, [0.5, -0.25]));
    expect(f.sampleRate, sr);
    expect(f.samples, [0.5, -0.25]);
    final p = decodeWav(wav(1, 16, [0.5, -0.25]));
    expect(p.samples[0], closeTo(0.5, 1e-4));
    expect(() => decodeWav(Uint8List(8)), throwsFormatException);
  });

  test('a quiet sound just before a click is not taken for it', () {
    final audio = room(times, delayMs: 424.6, noise: 0.0002, hum: 0);
    // A soft room sound 30 dB below the click, 7 ms before it.
    final at = times[4] + (0.4176 * sr).round();
    for (var k = 0; k < 400; k++) {
      audio[at + k] += 0.01 * (k.isEven ? 1 : -1);
    }
    final m = measureLatency(audio, sr, times)!;
    expect(m.each[4], closeTo(424.6, 1));
    expect(m.ok, isTrue);
  });
}
