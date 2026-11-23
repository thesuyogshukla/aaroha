import 'package:flutter/material.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../practice/practice_settings.dart';

const _latin = ['S', 'R', 'R', 'G', 'G', 'M', 'M', 'P', 'D', 'D', 'N', 'N'];
const _devanagari = ['सा', 'रे', 'रे', 'ग', 'ग', 'म', 'म', 'प', 'ध', 'ध', 'नि', 'नि'];

/// The syllable for a swar without its marks.
String swarText(Swar swar, Script script) =>
    (script == Script.latin ? _latin : _devanagari)[swar.index];

/// One swar in Bhatkhande style: komal underlined, a tick over tivra Ma, a dot
/// above for taar and below for mandra (docs/03-notation.md).
class SwarGlyph extends StatelessWidget {
  const SwarGlyph(this.pitch, {super.key, this.script = Script.latin, this.size = 32, this.color});

  final Pitch pitch;
  final Script script;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    final dot = Container(
      width: size * 0.16,
      height: size * 0.16,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    final gap = SizedBox(height: size * 0.16);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pitch.octave > 0)
          dot
        else if (pitch.swar.isTivra)
          Container(width: size * 0.07, height: size * 0.3, color: c)
        else
          gap,
        Text(
          swarText(pitch.swar, script),
          style: TextStyle(
            fontSize: size,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: c,
            decoration: pitch.swar.isKomal ? TextDecoration.underline : null,
            decorationColor: c,
            decorationThickness: 2,
          ),
        ),
        if (pitch.octave < 0) dot else gap,
      ],
    );
  }
}

/// A row of swars; [colors] (one per pitch) marks verdicts.
class SargamRow extends StatelessWidget {
  const SargamRow(
    this.pitches, {
    super.key,
    this.script = Script.latin,
    this.size = 32,
    this.colors,
  });

  final List<Pitch> pitches;
  final Script script;
  final double size;
  final List<Color?>? colors;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: size * 0.5,
    runSpacing: size * 0.3,
    children: [
      for (var i = 0; i < pitches.length; i++)
        SwarGlyph(pitches[i], script: script, size: size, color: colors?[i]),
    ],
  );
}

/// A phrase with its rhythm, the Bhatkhande way (docs/03-notation.md): one
/// group per matra, holds as `ऽ` (or `-` in Latin), rests as a faint `_`,
/// an arc under the notes that share a matra, and vibhag bars. A phrase of
/// one-matra notes looks exactly like [SargamRow]. [colors] has one entry
/// per sounding note (verdicts); a hold takes its note's colour.
class PhraseSargam extends StatelessWidget {
  const PhraseSargam(
    this.phrase, {
    super.key,
    this.script = Script.latin,
    this.size = 32,
    this.colors,
  });

  final Phrase phrase;
  final Script script;
  final double size;
  final List<Color?>? colors;

  @override
  Widget build(BuildContext context) {
    if (isEven(phrase)) {
      return SargamRow(phrase.pitches, script: script, size: size, colors: colors);
    }
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurface;
    final faint = scheme.outline;
    Color colorOf(int? note) => (note == null ? null : colors?[note]) ?? ink;

    // A symbol at the swar's text height, with the same space above and
    // below as a SwarGlyph, so everything sits on one line.
    Widget mark(String text, Color color, {FontWeight weight = FontWeight.w600}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: size * 0.16),
        Text(
          text,
          style: TextStyle(fontSize: size, height: 1.1, fontWeight: weight, color: color),
        ),
        SizedBox(height: size * 0.16),
      ],
    );

    Widget cell(NotationCell c) => switch (c.kind) {
      CellKind.note => SwarGlyph(c.pitch!, script: script, size: size, color: colorOf(c.note)),
      CellKind.hold => mark(script == Script.latin ? '-' : 'ऽ', colorOf(c.note)),
      CellKind.rest => mark('_', faint, weight: FontWeight.w400),
    };

    Widget matra(MatraItem m) {
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < m.cells.length; i++) ...[
            if (i > 0) SizedBox(width: size * 0.08),
            cell(m.cells[i]),
          ],
        ],
      );
      if (m.cells.length == 1) return row;
      // Notes sharing a matra get an arc underneath, as wide as they are.
      return IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            SizedBox(
              height: size * 0.22,
              child: CustomPaint(painter: _MatraArc(faint, size * 0.05)),
            ),
          ],
        ),
      );
    }

    final items = layoutNotation(phrase);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: size * 0.5,
      runSpacing: size * 0.3,
      children: [
        for (final item in items)
          switch (item) {
            MatraItem() => matra(item),
            BarItem(:final avartanEnd) => mark(
              avartanEnd ? '||' : '|',
              faint,
              weight: FontWeight.w300,
            ),
            BreakItem() => mark(',', faint),
          },
      ],
    );
  }
}

class _MatraArc extends CustomPainter {
  _MatraArc(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(width, width)
      ..quadraticBezierTo(size.width / 2, size.height * 1.6, size.width - width, width);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MatraArc old) => old.color != color || old.width != width;
}
