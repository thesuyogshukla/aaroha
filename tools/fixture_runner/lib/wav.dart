import 'dart:io';
import 'dart:typed_data';

class Wav {
  Wav(this.samples, this.sampleRate);

  /// First channel, as floats in -1..1.
  final Float32List samples;
  final int sampleRate;

  double get seconds => samples.length / sampleRate;
}

/// Reads PCM (16/24/32-bit) or IEEE float (32-bit) WAV files. Only the first
/// channel is kept.
Wav readWav(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw FormatException('not a WAV file', path);
  }

  int? format, channels, sampleRate, bits;
  for (var at = 12; at + 8 <= bytes.length;) {
    final id = tag(at);
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE) format = data.getUint16(body + 24, Endian.little);
    } else if (id == 'data') {
      if (format == null) throw FormatException('data before fmt', path);
      final stride = channels! * bits! ~/ 8;
      final available = (bytes.length - body).clamp(0, size);
      final frames = available ~/ stride;
      final out = Float32List(frames);
      for (var i = 0; i < frames; i++) {
        final p = body + i * stride;
        out[i] = switch ((format, bits)) {
          (3, 32) => data.getFloat32(p, Endian.little),
          (1, 16) => data.getInt16(p, Endian.little) / 32768.0,
          (1, 24) =>
            ((data.getUint8(p) | data.getUint8(p + 1) << 8 | data.getInt8(p + 2) << 16) /
                8388608.0),
          (1, 32) => data.getInt32(p, Endian.little) / 2147483648.0,
          _ => throw FormatException('unsupported WAV format $format/$bits-bit', path),
        };
      }
      return Wav(out, sampleRate!);
    }
    at = body + size + (size & 1);
  }
  throw FormatException('no data chunk', path);
}
