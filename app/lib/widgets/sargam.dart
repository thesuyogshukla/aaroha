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
