import 'dart:math' as math;

import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

String asciiOf(List<Pitch> pitches) => pitches.map((p) => p.ascii).join(' ');

void main() {
  group('practicePitches', () {
    test('swar set in madhya', () {
      expect(asciiOf(practicePitches(SwarSet.saToPa, SaptakRange.madhya)), 'S R G m P');
      expect(asciiOf(practicePitches(SwarSet.shuddha, SaptakRange.madhya)), 'S R G m P D N');
    });

    test('clipped to the flute range (.P to P\')', () {
      expect(
        asciiOf(practicePitches(SwarSet.shuddha, SaptakRange.all)),
        ".P .D .N S R G m P D N S' R' G' m' P'",
      );
      expect(practicePitches(SwarSet.all, SaptakRange.all).length, 25);
    });

    test('a narrower flute range clips further', () {
      final pitches = practicePitches(
        SwarSet.shuddha,
        SaptakRange.all,
        low: const Pitch(Swar.sa),
        high: const Pitch(Swar.sa, 1),
      );
      expect(asciiOf(pitches), "S R G m P D N S'");
    });
  });

  group('TargetGenerator', () {
    final pitches = practicePitches(SwarSet.shuddha, SaptakRange.madhya);

    test('singles never repeat back to back and cover the set', () {
      final g = TargetGenerator(pitches, random: math.Random(1));
      final seen = <Pitch>{};
      Pitch? last;
      for (var i = 0; i < 200; i++) {
        final t = g.single().single;
        expect(t, isNot(last));
        seen.add(t);
        last = t;
      }
      expect(seen, pitches.toSet());
    });

    test('phrases move by small steps within the set', () {
      final g = TargetGenerator(pitches, random: math.Random(2));
      for (var i = 0; i < 200; i++) {
        final phrase = g.phrase();
        expect(phrase.length, inInclusiveRange(2, 4));
        for (var k = 1; k < phrase.length; k++) {
          final step = (pitches.indexOf(phrase[k]) - pitches.indexOf(phrase[k - 1])).abs();
          expect(step, inInclusiveRange(1, 2));
        }
      }
    });

    test('one allowed pitch is fine', () {
      final g = TargetGenerator([const Pitch(Swar.sa)]);
      expect(g.single(), [const Pitch(Swar.sa)]);
      expect(g.phrase(), [const Pitch(Swar.sa)]);
    });
  });
}
