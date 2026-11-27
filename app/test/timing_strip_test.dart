import 'package:aaroha/widgets/timing_strip.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the timing strip draws only for a timed attempt', (tester) async {
    final phrase = parsePhrase('S - R G');
    DetectedNote at(int i, int onset, int length) => DetectedNote(
      pitch: phrase.pitches[i],
      onset: onset,
      end: onset + length,
      cents: Tuning.equal.centsOf(phrase.pitches[i]),
      deviation: 0,
      stability: 2,
    );
    final pitch = judgePhrase(phrase.pitches, [
      at(0, 0, 90000),
      at(1, 110000, 40000),
      at(2, 144000, 40000),
    ], const JudgeSettings());
    final timed = pitch.withRhythm(judgeRhythm(phrase, pitch, sams: const [0], matraFrames: 48000));
    Future<void> show(AttemptResult r) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: TimingStrip(phrase: phrase, result: r, taal: Taal.keherwa),
            ),
          ),
        ),
      ),
    );
    await show(timed);
    expect(find.bySemanticsLabel('2 on time, 0 early, 1 late'), findsOneWidget);
    expect(tester.getSize(find.byType(TimingStrip)).height, 64);
    await show(pitch);
    expect(tester.getSize(find.byType(TimingStrip)).height, 0, reason: 'no timing, nothing drawn');
  });
}
