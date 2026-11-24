import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:aaroha_core/aaroha_core.dart';

/// The clicks of one round as the beat strip draws them: when each sounds
/// (engine frames) and where it falls in the taal's cycle.
class BeatPlan {
  const BeatPlan(this.ticks, this.matraFrames);

  static const none = BeatPlan([], 0);

  final List<({int time, int position})> ticks;

  /// Engine frames per matra.
  final int matraFrames;

  bool get isEmpty => ticks.isEmpty;
}

/// The click sounding at [now] (engine frames, as heard): the last one at or
/// before it, for one matra or until the next click. Null between clicks
/// that are further apart (a count-in, then the call without a metronome),
/// before the first and after the last.
int? soundingTick(BeatPlan plan, int now) {
  final ticks = plan.ticks;
  int? found;
  for (var i = 0; i < ticks.length && ticks[i].time <= now; i++) {
    found = i;
  }
  if (found == null || now - ticks[found].time >= plan.matraFrames) return null;
  return found;
}

/// How the start of each vibhag is written in taal notation: × for sam, 0 for
/// khali, then the talis numbered from 2 (teentaal: × 2 0 3).
List<String> vibhagMarks(Taal taal) {
  var tali = 2;
  return [
    for (var v = 0; v < taal.vibhags.length; v++)
      v == 0
          ? '×'
          : taal.khali.contains(v)
          ? '0'
          : '${tali++}',
  ];
}

/// A row of dots, one per matra of [taal], grouped by vibhag, lighting up
/// with each click as it is heard (docs/08 M3-B). Without a taal, one dot
/// that flashes on each click.
///
/// [now] gives the engine time the player is hearing: the engine's clock
/// less the sound delay.
class BeatStrip extends StatefulWidget {
  const BeatStrip({super.key, required this.taal, required this.plan, required this.now});

  final Taal? taal;
  final BeatPlan plan;
  final int Function() now;

  @override
  State<BeatStrip> createState() => _BeatStripState();
}

class _BeatStripState extends State<BeatStrip> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int? _position;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _update())..start();
    _update();
  }

  void _update() {
    final now = widget.now();
    final i = soundingTick(widget.plan, now);
    final position = i == null ? null : widget.plan.ticks[i].position;
    // Without a taal the dot flashes for the first part of each matra.
    final flash = i != null && now - widget.plan.ticks[i].time < widget.plan.matraFrames * 0.35;
    if (position != _position || flash != _flash) {
      setState(() {
        _position = position;
        _flash = flash;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    Widget dot({required bool lit, required bool sam}) => AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: lit ? 14 : 10,
      height: lit ? 14 : 10,
      margin: EdgeInsets.symmetric(horizontal: lit ? 2 : 4, vertical: lit ? 0 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: lit || sam ? scheme.primary : scheme.outline,
          width: sam ? 2.5 : 1.5,
        ),
      ),
    );

    final taal = widget.taal;
    if (taal == null) {
      return Semantics(
        label: 'Beat',
        child: dot(lit: _flash, sam: true),
      );
    }
    final marks = vibhagMarks(taal);
    var start = 0;
    final groups = <Widget>[];
    for (var v = 0; v < taal.vibhags.length; v++) {
      final first = start;
      groups.add(
        Padding(
          padding: EdgeInsets.only(left: v == 0 ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var m = first; m < first + taal.vibhags[v]; m++)
                      dot(lit: m == _position, sam: m == 0),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Under the vibhag's first dot.
              SizedBox(
                width: 18,
                child: Text(marks[v], textAlign: TextAlign.center, style: small),
              ),
            ],
          ),
        ),
      );
      start += taal.vibhags[v];
    }
    return Semantics(
      label: '${taal.label}: ${taal.shape}',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: groups),
      ),
    );
  }
}
