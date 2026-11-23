import 'dart:io';
import 'dart:typed_data';

import 'package:aaroha_core/aaroha_core.dart';

class Wav {
  Wav(this.samples, this.sampleRate);

  /// First channel, as floats in -1..1.
  final Float32List samples;
  final int sampleRate;

  double get seconds => samples.length / sampleRate;
}

/// Reads PCM (16/24/32-bit) or IEEE float (32-bit) WAV files (see
/// [decodeWav]).
Wav readWav(String path) {
  final wav = decodeWav(File(path).readAsBytesSync(), source: path);
  return Wav(wav.samples, wav.sampleRate);
}
