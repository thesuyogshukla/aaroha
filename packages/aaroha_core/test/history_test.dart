import 'dart:math' as math;

import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

Pitch p(String ascii) => parsePhrase(ascii).pitches.single;

final now = DateTime(2026, 11, 22, 20);

NoteOutcome o(
  String target,
  Verdict verdict, {
  String? played,
  double? cents,
  int daysAgo = 0,
  int? flute,
}) => NoteOutcome(
  target: p(target),
  verdict: verdict,
  played: played == null ? null : p(played),
  cents: cents,
  fluteId: flute,
  at: now.subtract(Duration(days: daysAgo, minutes: 1)),
);

void main() {
  group('PracticeHistory', () {
    test('counts first tries and misses; out of tune is not a miss', () {
      final h = PracticeHistory(
        [o('G', Verdict.pass), o('G', Verdict.outOfTune), o('G', Verdict.wrongSwar, played: 'm')],
        40,
        now,
      );
      final r = h.recordOf(p('G'));
      expect(r.tries, 3);
      expect(r.misses, 1);
      expect(r.accuracy, closeTo(2 / 3, 1e-9));
    });

    test('only the most recent window counts', () {
      final h = PracticeHistory(
        [
          for (var i = 0; i < 10; i++) o('S', Verdict.wrongSwar, played: 'R', daysAgo: 30),
          for (var i = 0; i < 5; i++) o('S', Verdict.pass),
        ],
        5,
        now,
      );
      expect(h.recordOf(p('S')).misses, 0);
    });

    test('a swar you miss weighs more than one you know', () {
      final h = PracticeHistory(
        [
          for (var i = 0; i < 10; i++) o('G', Verdict.wrongSwar, played: 'm'),
          for (var i = 0; i < 10; i++) o('P', Verdict.pass),
        ],
        40,
        now,
      );
      expect(h.weight(p('G')), greaterThan(4 * h.weight(p('P'))));
      expect(h.weight(p('P')), greaterThan(0), reason: 'known swars still come up');
    });

    test('swars not practised for a while weigh more', () {
      final h = PracticeHistory([o('S', Verdict.pass, daysAgo: 10), o('R', Verdict.pass)], 40, now);
      expect(h.weight(p('S')), closeTo(2 * h.weight(p('R')), 1e-3));
    });

    test('confusions and confused pairs', () {
      final h = PracticeHistory(
        [
          o('G', Verdict.wrongSwar, played: 'm'),
          o('G', Verdict.wrongSwar, played: 'm'),
          o('G', Verdict.wrongSwar, played: 'm'),
          o('D', Verdict.wrongSwar, played: 'P'),
          o('D', Verdict.wrongSwar, played: 'P'),
          o('N', Verdict.wrongOctave, played: '.N'),
          o('R', Verdict.outOfTune, played: 'R'),
          o('m', Verdict.wrongSwar, played: 'm'), // 52 c sharp, nearest allowed swar still Ma
        ],
        40,
        now,
      );
      expect(h.confusions[(p('G'), p('m'))], 3);
      expect(h.confusions.containsKey((p('R'), p('R'))), isFalse);
      expect(h.confusions.containsKey((p('m'), p('m'))), isFalse);
      expect(h.recordOf(p('m')).misses, 1, reason: 'still a miss');
      expect(h.confusedPairs(), [(p('G'), p('m')), (p('D'), p('P'))]);
    });

    test('intonation per flute, in the tuning asked for', () {
      final h = PracticeHistory(
        [
          o('N', Verdict.outOfTune, played: 'N', cents: 1070, flute: 1),
          o('N', Verdict.pass, played: 'N', cents: 1074, flute: 1),
          o('N', Verdict.pass, played: 'N', cents: 1100, flute: 2),
          o('N', Verdict.wrongSwar, played: 'D', cents: 900, flute: 1),
        ],
        40,
        now,
      );
      final equal = h.intonation(Tuning.equal, fluteId: 1)[p('N')]!;
      expect(equal.mean, closeTo(-28, 1e-9));
      expect(equal.count, 2);
      final just = h.intonation(Tuning.just, fluteId: 1)[p('N')]!;
      expect(just.mean, closeTo(1072 - 1088.27, 1e-9));
    });
  });

  group('TargetGenerator with history', () {
    final pitches = practicePitches(SwarSet.shuddha, SaptakRange.madhya);

    test('picks heavy swars more often', () {
      final g = TargetGenerator(
        pitches,
        random: math.Random(3),
        weightOf: (x) => x == p('G') ? 10 : 1,
        contrastChance: 0,
      );
      final counts = <Pitch, int>{};
      for (var i = 0; i < 2000; i++) {
        final t = g.single().single;
        counts[t] = (counts[t] ?? 0) + 1;
      }
      expect(counts[p('G')]!, greaterThan(3 * counts[p('P')]!));
      expect(counts.keys.toSet(), pitches.toSet(), reason: 'every swar still comes up');
    });

    test('a contrast drill plays the confused pair back to back', () {
      final g = TargetGenerator(
        pitches,
        random: math.Random(4),
        pairs: () => [(p('G'), p('m'))],
        contrastChance: 1,
      );
      expect(g.single(), [p('G')]);
      expect(g.single(), [p('m')]);
      expect(g.phrase(), [p('G'), p('m')]);
    });

    test('pairs outside the allowed set are ignored', () {
      final g = TargetGenerator(
        practicePitches(SwarSet.saToPa, SaptakRange.madhya),
        random: math.Random(5),
        pairs: () => [(p('D'), p('N'))],
        contrastChance: 1,
      );
      for (var i = 0; i < 50; i++) {
        expect([p('D'), p('N')], isNot(contains(g.single().single)));
      }
    });
  });
}
