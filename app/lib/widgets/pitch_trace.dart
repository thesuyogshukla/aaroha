import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';

import '../practice/practice_settings.dart';
import 'sargam.dart';

/// The player's pitch curve over one attempt, against the target swars
/// (docs/05 §10). Shown only after the verdict, never while playing.
///
/// Each target swar is a lane with its tolerance band. The curve is coloured
/// by the verdict of the note it belongs to: in tune, right swar but out of
/// tune, or wrong; stretches between notes (slides, breaths) are grey.
class PitchTraceView extends StatelessWidget {
  const PitchTraceView(
    this.trace, {
    super.key,
    this.script = Script.latin,
    this.toleranceCents = 25,
  });

  final PitchTrace trace;
  final Script script;
  final double toleranceCents;

  static const _gutter = 36.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        if (height < 60 || trace.isEmpty) return const SizedBox.shrink();
        double y(double cents) =>
            8 + (height - 16) * (trace.high - cents) / (trace.high - trace.low);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TracePainter(
                  trace,
                  y: y,
                  gutter: _gutter,
                  tolerance: toleranceCents,
                  colors: _TraceColors(
                    lane: scheme.outlineVariant,
                    grid: scheme.outlineVariant.withValues(alpha: 0.25),
                    band: scheme.primary.withValues(alpha: 0.08),
                    pass: scheme.primary,
                    outOfTune: scheme.tertiary,
                    wrong: scheme.error,
                    between: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            for (final lane in trace.lanes)
              Positioned(
                left: 0,
                width: _gutter - 6,
                top: y(lane.cents),
                child: FractionalTranslation(
                  translation: const Offset(0, -0.5),
                  child: Center(
                    child: SwarGlyph(
                      lane.pitch,
                      script: script,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TraceColors {
  const _TraceColors({
    required this.lane,
    required this.grid,
    required this.band,
    required this.pass,
    required this.outOfTune,
    required this.wrong,
    required this.between,
  });
  final Color lane, grid, band, pass, outOfTune, wrong, between;
}

class _TracePainter extends CustomPainter {
  _TracePainter(
    this.trace, {
    required this.y,
    required this.gutter,
    required this.tolerance,
    required this.colors,
  });

  final PitchTrace trace;
  final double Function(double cents) y;
  final double gutter;
  final double tolerance;
  final _TraceColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - gutter;
    double x(double seconds) => gutter + width * seconds / trace.duration;

    // A faint line at every semitone, so distances read without names.
    final grid = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (var c = (trace.low / 100).ceil() * 100.0; c <= trace.high; c += 100) {
      canvas.drawLine(Offset(gutter, y(c)), Offset(size.width, y(c)), grid);
    }

    // Lanes: the tolerance band, then the line itself.
    final band = Paint()..color = colors.band;
    final lane = Paint()
      ..color = colors.lane
      ..strokeWidth = 1;
    for (final l in trace.lanes) {
      final top = y(l.cents + tolerance), bottom = y(l.cents - tolerance);
      canvas.drawRect(Rect.fromLTRB(gutter, top, size.width, bottom), band);
      canvas.drawLine(Offset(gutter, y(l.cents)), Offset(size.width, y(l.cents)), lane);
    }

    Color colorAt(double seconds) {
      final verdict = trace.noteAt(seconds)?.judged.verdict;
      return switch (verdict) {
        null => colors.between,
        Verdict.pass => colors.pass,
        Verdict.outOfTune => colors.outOfTune,
        _ => colors.wrong,
      };
    }

    // The curve, one colour per stretch.
    for (final line in trace.lines) {
      if (line.length == 1) {
        final p = line.single;
        canvas.drawCircle(
          Offset(x(p.seconds), y(p.cents)),
          1.5,
          Paint()..color = colorAt(p.seconds),
        );
        continue;
      }
      var path = Path()..moveTo(x(line.first.seconds), y(line.first.cents));
      var color = colorAt(line.first.seconds);
      for (var i = 1; i < line.length; i++) {
        final p = line[i];
        final c = colorAt(p.seconds);
        path.lineTo(x(p.seconds), y(p.cents));
        if (c != color || i == line.length - 1) {
          canvas.drawPath(path, _stroke(color));
          path = Path()..moveTo(x(p.seconds), y(p.cents));
          color = c;
        }
      }
    }
  }

  Paint _stroke(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_TracePainter old) => old.trace != trace || old.tolerance != tolerance;
}
