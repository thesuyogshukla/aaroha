/// One output frame of the native pitch tracker (docs/04-architecture.md).
class PitchFrame {
  const PitchFrame({
    required this.time,
    required this.hz,
    required this.confidence,
    required this.rms,
  });

  /// Engine frame (sample index) at the centre of the analysis window.
  final int time;

  /// 0 when the tracker found no pitch.
  final double hz;

  /// 1 - YIN aperiodicity, 0..1.
  final double confidence;

  /// Loudness of the analysis window.
  final double rms;

  @override
  String toString() =>
      'PitchFrame(t=$time, ${hz.toStringAsFixed(2)} Hz, '
      'c=${confidence.toStringAsFixed(2)}, rms=${rms.toStringAsExponential(2)})';
}
