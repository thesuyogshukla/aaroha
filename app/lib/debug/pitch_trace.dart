import 'package:flutter/material.dart';
import 'package:aaroha_core/aaroha_core.dart';

/// Scrolling plot of cents from Sa, with a line for every shuddha swar from
/// mandra Pa to taar Pa.
class PitchTrace extends StatelessWidget {
  const PitchTrace({super.key, required this.trace, required this.length});

  final List<double?> trace;
  final int length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _TracePainter(
        trace: trace,
        length: length,
        line: scheme.primary,
        grid: scheme.outlineVariant,
        saGrid: scheme.outline,
        label: scheme.onSurfaceVariant,
      ),
      size: Size.infinite,
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.trace,
    required this.length,
    required this.line,
    required this.grid,
    required this.saGrid,
    required this.label,
  });

  final List<double?> trace;
  final int length;
  final Color line;
  final Color grid;
  final Color saGrid;
  final Color label;

  static const _low = -600.0;
  static const _high = 1800.0;
  static const _labelWidth = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _labelWidth;
    double y(double cents) => size.height * (1 - (cents - _low) / (_high - _low));

    final gridPaint = Paint()..strokeWidth = 1;
    for (var octave = -1; octave <= 1; octave++) {
      for (final swar in Swar.values.where((s) => !s.isKomal && !s.isTivra)) {
        final pitch = Pitch(swar, octave);
        final cents = Tuning.equal.centsOf(pitch);
        if (cents < _low || cents > _high) continue;
        final isSa = swar == Swar.sa;
        gridPaint.color = isSa ? saGrid : grid;
        canvas.drawLine(Offset(_labelWidth, y(cents)), Offset(size.width, y(cents)), gridPaint);
        final text = TextPainter(
          text: TextSpan(
            text: pitch.ascii,
            style: TextStyle(
              color: label,
              fontSize: 10,
              fontWeight: isSa ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(0, y(cents) - text.height / 2));
      }
    }

    final paint = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dx = plotWidth / length;
    final start = length - trace.length;
    Path? path;
    for (var i = 0; i < trace.length; i++) {
      final cents = trace[i];
      if (cents == null || cents < _low || cents > _high) {
        if (path != null) canvas.drawPath(path, paint);
        path = null;
        continue;
      }
      final point = Offset(_labelWidth + (start + i) * dx, y(cents));
      if (path == null) {
        path = Path()..moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TracePainter old) => !identical(old.trace, trace);
}
