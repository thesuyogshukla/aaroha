import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';

import '../practice/practice_settings.dart';
import 'beat_strip.dart';
import 'sargam.dart';

/// One attempt's timing (docs/08 M3-E): the phrase's matras as a grid, each
/// written note as a pale bar where it belongs, and under it what was played,
/// from where it started to where it stopped. Played bars are in the main
/// colour when on time and held, in the in-between colour when early, late
/// or held too short. Vibhags are marked × 0 2 3 as on the beat strip.
class TimingStrip extends StatelessWidget {
  const TimingStrip({
    super.key,
    required this.phrase,
    required this.result,
    this.taal,
    this.start = 0,
    this.script = Script.latin,
    this.showNames = true,
  });

  final Phrase phrase;
  final AttemptResult result;
  final Taal? taal;

  /// Where in the taal's cycle the phrase starts, in matras after sam (D57):
  /// the vibhag marks fall where the taal puts them.
  final int start;
  final Script script;

  /// False while the target is hidden: the bars are drawn without swars.
  final bool showNames;

  @override
  Widget build(BuildContext context) {
    final rhythm = result.rhythm;
    if (rhythm == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final targets = result.targets;
    final written = phrase.sounding;
    final played = <({double from, double to, bool good})?>[
      for (var i = 0; i < targets.length; i++)
        targets[i].played == null || rhythm.notes[i] == null
            ? null
            : (
                from: rhythm.matraAt(targets[i].played!.onset),
                to: rhythm.matraAt(targets[i].played!.end),
                good: rhythm.notes[i]!.good,
              ),
    ];
    return Semantics(
      label: _describe(rhythm),
      child: SizedBox(
        height: 64,
        child: CustomPaint(
          size: Size.infinite,
          painter: _StripPainter(
            length: phrase.length.toDouble(),
            written: [
              for (final n in written)
                (
                  from: n.start.toDouble(),
                  to: n.end.toDouble(),
                  name: showNames ? _name(n.pitch!, script) : '',
                  komal: n.pitch!.swar.isKomal,
                ),
            ],
            played: played,
            taal: taal,
            start: start,
            text: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
            grid: scheme.outlineVariant,
            writtenColor: scheme.surfaceContainerHighest,
            good: scheme.primary,
            off: scheme.tertiary,
          ),
        ),
      ),
    );
  }

  /// The swar with its marks as in the ASCII notation (docs/03): a dot
  /// before for mandra, an apostrophe after for taar, a tick before tivra
  /// Ma. Komal is underlined when drawn.
  static String _name(Pitch p, Script script) =>
      '${p.octave < 0 ? '.' : ''}${p.swar.isTivra ? 'ˈ' : ''}${swarText(p.swar, script)}'
      '${p.octave > 0 ? "'" : ''}';

  static String _describe(RhythmResult r) =>
      '${r.count(Timing.onTime)} on time, ${r.count(Timing.early)} early, '
      '${r.count(Timing.late)} late';
}

typedef _Bar = ({double from, double to, String name, bool komal});

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.length,
    required this.written,
    required this.played,
    required this.taal,
    required this.start,
    required this.text,
    required this.grid,
    required this.writtenColor,
    required this.good,
    required this.off,
  });

  final double length;
  final List<_Bar> written;
  final List<({double from, double to, bool good})?> played;
  final Taal? taal;
  final int start;
  final TextStyle text;
  final Color grid, writtenColor, good, off;

  // Half a matra of room either side, for notes played early or late.
  static const _pad = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (length <= 0) return;
    final span = length + 2 * _pad;
    double x(double matra) => (matra.clamp(-_pad, length + _pad) + _pad) / span * size.width;
    const writtenTop = 4.0, writtenHeight = 20.0;
    const playedTop = 28.0, playedHeight = 12.0;
    const marksTop = 46.0;

    // The matras, a stronger line where a vibhag starts.
    final starts = <int, String>{};
    if (taal != null) {
      final marks = vibhagMarks(taal!);
      var at = 0;
      for (var v = 0; v < taal!.vibhags.length; v++) {
        starts[at] = marks[v];
        at += taal!.vibhags[v];
      }
    }
    for (var m = 0; m <= length.ceil(); m++) {
      final inCycle = taal == null ? -1 : (start + m) % taal!.matras;
      final strong = starts.containsKey(inCycle);
      canvas.drawLine(
        Offset(x(m.toDouble()), 0),
        Offset(x(m.toDouble()), playedTop + playedHeight + 2),
        Paint()
          ..color = grid.withValues(alpha: strong ? 0.9 : 0.4)
          ..strokeWidth = strong ? 1.5 : 1,
      );
      if (strong && m < length) {
        _label(canvas, starts[inCycle]!, Offset(x(m.toDouble()), marksTop), center: true);
      }
    }

    for (var i = 0; i < written.length; i++) {
      final w = written[i];
      final r = RRect.fromLTRBR(
        x(w.from) + 1,
        writtenTop,
        x(w.to) - 1,
        writtenTop + writtenHeight,
        const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = writtenColor);
      if (w.name.isNotEmpty) {
        _label(canvas, w.name, Offset(x(w.from) + 4, writtenTop + 3), underline: w.komal);
      }
      final p = played[i];
      if (p == null) continue;
      // A note ends, on the strip, where the next one played starts.
      final next = played.skip(i + 1).nonNulls.firstOrNull;
      final from = x(p.from);
      final to = next == null || next.from > p.to ? x(p.to) : x(next.from) - 2;
      canvas.drawRRect(
        RRect.fromLTRBR(
          from,
          playedTop,
          to < from + 3 ? from + 3 : to,
          playedTop + playedHeight,
          const Radius.circular(3),
        ),
        Paint()..color = p.good ? good : off,
      );
    }
  }

  void _label(Canvas canvas, String s, Offset at, {bool center = false, bool underline = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: underline ? text.copyWith(decoration: TextDecoration.underline) : text,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.length != length || old.played != played || old.written != written || old.start != start;
}
