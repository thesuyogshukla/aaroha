import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaroha/widgets/beat_strip.dart';
import 'package:aaroha_core/aaroha_core.dart';

void main() {
  // Keherwa at 75 a minute (38400 frames a matra), free start: the call's
  // six matras and the turn's first five, the cycle carrying on.
  final r = roundClicks(callMatras: 6, responseMatras: 5, taal: Taal.keherwa, metronome: true);
  const matra = 38400;
  final plan = BeatPlan([
    for (final c in r.clicks) (time: 1000 + c.matra * matra, position: c.position),
  ], matra);

  test('the click sounding is the last one heard, for a matra', () {
    expect(soundingTick(plan, 999), isNull, reason: 'before the first');
    expect(soundingTick(plan, 1000), 0);
    expect(soundingTick(plan, 1000 + matra - 1), 0);
    expect(soundingTick(plan, 1000 + 7 * matra), 7);
    expect(plan.ticks[8].position, 0, reason: 'the turn reaches sam two matras after the call');
    expect(soundingTick(plan, 1000 + 10 * matra + matra ~/ 2), 10);
    expect(soundingTick(plan, 1000 + 11 * matra), isNull, reason: 'after the last');
  });

  test('a count-in without a metronome lights only the count-in', () {
    final c = roundClicks(callMatras: 6, responseMatras: 0, taal: Taal.keherwa, countIn: true);
    final p = BeatPlan([
      for (final k in c.clicks) (time: k.matra * matra, position: k.position),
    ], matra);
    expect(soundingTick(p, 3 * matra + 10), 3);
    expect(soundingTick(p, 6 * matra), isNull, reason: 'the call, unclicked');
  });

  test('vibhags are marked as in taal notation', () {
    expect(vibhagMarks(Taal.teentaal), ['×', '2', '0', '3']);
    expect(vibhagMarks(Taal.keherwa), ['×', '0']);
    expect(vibhagMarks(Taal.dadra), ['×', '0']);
  });

  testWidgets('the strip draws one dot per matra and lights the sounding one', (tester) async {
    var now = 1000 + 8 * matra + 10; // the turn's first sam
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BeatStrip(taal: Taal.keherwa, plan: plan, now: () => now),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final dots = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    expect(dots, hasLength(8));
    Color? fill(AnimatedContainer c) => (c.decoration as BoxDecoration?)?.color;
    final lit = [for (final d in dots) fill(d) != Colors.transparent];
    expect(lit, [true, false, false, false, false, false, false, false]);
    expect(find.text('×'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    now = 1000 + 9 * matra + 10;
    await tester.pump(const Duration(milliseconds: 100));
    final next = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    expect([for (final d in next) fill(d) != Colors.transparent].indexOf(true), 1);
  });
}
