import 'dart:io';
import 'dart:math' as math;

import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

List<Pitch> ps(String ascii) => parsePhrase(ascii).pitches;

final contentDir = Directory('../../content');

List<Raga> loadRagas() => [
  for (final f in Directory(
    '${contentDir.path}/ragas',
  ).listSync()..sort((a, b) => a.path.compareTo(b.path)))
    if (f.path.endsWith('.yaml')) Raga.fromYaml(File(f.path).readAsStringSync()),
];

void main() {
  group('shipped content', () {
    test('every raga file parses, with source and license', () {
      final ragas = loadRagas();
      expect(ragas.map((r) => r.id), [
        'bhairav',
        'bhupali',
        'bilawal',
        'des',
        'durga',
        'kafi',
        'khamaj',
        'yaman',
      ]);
      for (final r in ragas) {
        expect(r.license, 'public-domain', reason: r.id);
        expect(r.pakad, isNotEmpty, reason: r.id);
        expect(r.chalan, isNotEmpty, reason: r.id);
      }
    });

    test('every raga phrase fits a medium flute (mandra Pa to taar Pa)', () {
      for (final r in loadRagas()) {
        final drill = RagaDrill(r);
        final all = [
          r.aaroh,
          r.avaroh,
          ...r.pakad,
          ...r.chalan,
        ].expand((p) => splitAtBreaks(p)).length;
        expect(drill.pool.length, all, reason: '${r.id}: a phrase is out of range');
      }
    });

    test('alankars parse', () {
      final alankars = Alankar.listFromYaml(
        File('${contentDir.path}/alankars/basic.yaml').readAsStringSync(),
      );
      expect(alankars.first.pattern, [0]);
      expect(alankars.map((a) => a.id).toSet().length, alankars.length);
    });

    test('rhythm lessons parse, fit a medium flute, and have unique ids', () {
      final lessons = [
        for (final f in Directory(
          '${contentDir.path}/rhythm',
        ).listSync()..sort((a, b) => a.path.compareTo(b.path)))
          if (f.path.endsWith('.yaml'))
            ...RhythmLesson.listFromYaml(File(f.path).readAsStringSync()),
      ];
      expect({for (final l in lessons) l.taal}, {Taal.keherwa, Taal.dadra});
      expect(lessons.map((l) => l.id).toSet().length, lessons.length);
      final low = Tuning.equal.centsOf(const Pitch(Swar.pa, -1));
      final high = Tuning.equal.centsOf(const Pitch(Swar.pa, 1));
      for (final l in lessons) {
        expect(l.license, 'original', reason: l.id);
        expect(l.phrases, isNotEmpty, reason: l.id);
        for (final p in l.phrases) {
          for (final pitch in p.pitches) {
            final c = Tuning.equal.centsOf(pitch);
            expect(c >= low && c <= high, isTrue, reason: '${l.id}: $pitch');
          }
          // Printed and parsed back the same, as rounds are stored.
          expect(parsePhrase(printNotation(p)), p, reason: '${l.id}: ${printNotation(p)}');
        }
      }
    });
  });

  group('RhythmLesson', () {
    test('a phrase must end on a vibhag and match the taal', () {
      String file(String phrase) =>
          'taal: keherwa\nsource: s\nlicense: l\nlessons:\n  - id: x\n    name: X\n'
          '    phrases: ["$phrase"]\n';
      expect(RhythmLesson.listFromYaml(file('S R G m')).single.phrases.single.length, Fraction(4));
      expect(() => RhythmLesson.listFromYaml(file('S R G')), throwsFormatException);
      expect(() => RhythmLesson.listFromYaml(file('S R | G m ||')), throwsFormatException);
      expect(() => RhythmLesson.listFromYaml(file('S - - -')), throwsFormatException);
    });

    test('RhythmDrill plays the lesson in order, then at random without repeats', () {
      final lesson = RhythmLesson(
        id: 'x',
        name: 'X',
        taal: Taal.keherwa,
        source: '',
        license: '',
        phrases: [
          for (final t in ['S R G m', 'S - R -', 'G - R S']) parsePhrase(t),
        ],
      );
      final drill = RhythmDrill(lesson, random: math.Random(1));
      final first = [for (var i = 0; i < 3; i++) printNotation(drill.next().phrase)];
      expect(first, ['S R G m', 'S - R -', 'G - R S']);
      var last = first.last;
      for (var i = 0; i < 50; i++) {
        final d = printNotation(drill.next().phrase);
        expect(d, isNot(last));
        last = d;
      }
    });
  });

  group('Raga', () {
    test('rejects a swar outside the raga', () {
      expect(
        () => Raga.fromYaml('''
id: x
name: X
swars: [S, R, G, P, D]
aaroh: "S R G m P"
avaroh: "S"
source: traditional
license: public-domain
'''),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('aaroh'))),
      );
    });

    test('aaroh and avaroh swars skip vakra turns and the mandra', () {
      final des = loadRagas().firstWhere((r) => r.id == 'des');
      expect(des.aarohSwars, {Swar.sa, Swar.re, Swar.ma, Swar.pa, Swar.ni});
      expect(des.avarohSwars, {
        Swar.sa,
        Swar.komalNi,
        Swar.dha,
        Swar.pa,
        Swar.ma,
        Swar.ga,
        Swar.re,
      });
      final yaman = loadRagas().firstWhere((r) => r.id == 'yaman');
      expect(yaman.aarohSwars, isNot(contains(Swar.pa)));
    });
  });

  group('alankar walk', () {
    final madhya = scaleDegrees(SwarSet.shuddha.swars, SaptakRange.madhya);

    test('scale degrees run Sa to taar Sa', () {
      expect(madhya, ps("S R G m P D N S'"));
    });

    test('groups of three, up then mirrored down', () {
      const a = Alankar(id: 'a', name: 'Groups of three', pattern: [0, 1, 2]);
      final w = a.walk(madhya, madhya);
      expect(w.up.first, ps('S R G'));
      expect(w.up.last, ps("D N S'"));
      expect(w.up.length, 6);
      expect(w.down.first, ps("S' N D"));
      expect(w.down.last, ps('G R S'));
    });

    test('rounds hold whole groups, up to four notes', () {
      const straight = Alankar(id: 'a', name: 'Straight', pattern: [0]);
      final rounds = alankarRounds(straight, madhya, madhya);
      expect(
        [for (final r in rounds) r.pitches],
        [ps('S R G m'), ps("P D N S'"), ps("S' N D P"), ps('m G R S')],
      );
      expect(rounds.first.label, 'Aaroh');
      expect(rounds.last.label, 'Avaroh');
      expect(
        [for (final r in alankarRounds(straight, madhya, madhya, maxNotes: 6)) r.pitches.length],
        [4, 4, 4, 4],
        reason: 'spread evenly, not 6 + 2',
      );
      expect(
        [for (final r in alankarRounds(straight, madhya, madhya, maxNotes: 8)) r.pitches.length],
        [8, 8],
      );
      const three = Alankar(id: 'b', name: 'Groups of three', pattern: [0, 1, 2]);
      expect(alankarRounds(three, madhya, madhya).first.pitches, ps('S R G'));
    });

    test('a raga walks its aaroh up and its avaroh down', () {
      final des = loadRagas().firstWhere((r) => r.id == 'des');
      final up = scaleDegrees(des.aarohSwars, SaptakRange.madhya);
      final down = scaleDegrees(des.avarohSwars, SaptakRange.madhya);
      final rounds = alankarRounds(const Alankar(id: 'a', name: 's', pattern: [0]), up, down);
      expect(rounds.first.pitches, ps('S R m'), reason: '6 notes up: 3 + 3');
      expect(rounds[1].pitches, ps("P N S'"));
      expect(rounds.last.pitches, ps('m G R S'));
    });

    test('degrees stay within the flute', () {
      final d = scaleDegrees(
        SwarSet.shuddha.swars,
        SaptakRange.all,
        low: const Pitch(Swar.pa, -1),
        high: const Pitch(Swar.pa, 1),
      );
      expect(d.first, const Pitch(Swar.pa, -1));
      expect(d.last, const Pitch(Swar.pa, 1));
    });
  });

  group('PhraseLevel', () {
    test('lengths per level', () {
      expect([for (var l = 1; l <= 5; l++) PhraseLevel.maxNotes(l)], [4, 5, 6, 7, 8]);
      expect([for (var l = 1; l <= 5; l++) PhraseLevel.minNotes(l)], [2, 3, 4, 5, 6]);
    });

    test('goes up after 8 of the last 10 right, then starts counting again', () {
      final t = PhraseLevelTracker();
      for (var i = 0; i < 7; i++) {
        expect(t.add(true), 0);
      }
      expect(t.add(false), 0);
      expect(t.add(false), 0);
      expect(t.add(true), 1, reason: '8 of 10');
      expect(t.level, 2);
      expect(t.recent, isEmpty);
    });

    test('goes down after 4 or fewer of the last 10, never below 1', () {
      final t = PhraseLevelTracker(level: 2);
      for (var i = 0; i < 9; i++) {
        t.add(i < 4);
      }
      expect(t.add(false), -1);
      expect(t.level, 1);
      for (var i = 0; i < 10; i++) {
        t.add(false);
      }
      expect(t.level, 1);
    });

    test('a sliding window: an early streak counts once ten are in', () {
      final t = PhraseLevelTracker();
      for (var i = 0; i < 5; i++) {
        t.add(false);
      }
      for (var i = 0; i < 12; i++) {
        t.add(true);
      }
      expect(t.level, 2, reason: 'the last 10 were 9 or 10 right');
      final back = PhraseLevelTracker.fromJson(t.toJson());
      expect(back.level, t.level);
      expect(back.recent, t.recent);
    });
  });

  group('RagaDrill', () {
    test('long phrases split at their breaks', () {
      List<String> split(String text, {int maxNotes = 8}) => [
        for (final p in splitAtBreaks(parsePhrase(text), maxNotes: maxNotes)) printNotation(p),
      ];
      expect(split('G R S .D , S R G , P G , D P G R S'), ['G R S .D S R G', 'P G D P G R S']);
      // A run longer than the limit is cut into pieces that share a note.
      expect(split("S R G m P D N S' R'"), ['S R G m P', "P D N S' R'"]);
      expect(split("S R G P D S'", maxNotes: 4), ['S R G P', "P D S'"]);
      expect(split("S R G P D S'", maxNotes: 3), ['S R G', 'G P', "P D S'"]);
    });

    test('pieces keep their written timing', () {
      List<String> split(String text, {int maxNotes = 8}) => [
        for (final p in splitAtBreaks(parsePhrase(text), maxNotes: maxNotes)) printNotation(p),
      ];
      expect(split('S - RG m , P - D'), ['S - RG m P - D'], reason: 'joined, carrying on');
      // A piece that starts inside a matra keeps its place in it.
      expect(split('S - RG m , P - DP mG', maxNotes: 4), ['S - RG m', 'P - DP', '_P mG']);
      // Rests inside a part stay; rests at its edges and bars go.
      expect(split('_ S _ R _ , G', maxNotes: 2), ['S _ R', 'G']);
      expect(split('S R | G m ||'), ['S R G m']);
      expect(split('S-R G', maxNotes: 2), ['S-R', '__R G']);
    });

    test('untimed material is even', () {
      expect(isEven(evenPhrase(ps("S R G m P D N S'"))), isTrue);
      expect(isEven(parsePhrase('S R G')), isTrue);
      expect(isEven(parsePhrase('S - R')), isFalse);
      expect(isEven(parsePhrase('SR G')), isFalse);
      expect(isEven(parsePhrase('S _ R')), isFalse);
      expect(isEven(parsePhrase('S R | G m')), isFalse);
      expect(printNotation(evenPhrase(ps('S R G'))), 'S R G');
    });

    test('opens with every aaroh piece, then every avaroh piece', () {
      final bhupali = loadRagas().firstWhere((r) => r.id == 'bhupali');
      final drill = RagaDrill(bhupali, maxNotes: 4, random: math.Random(2));
      expect(
        [for (var i = 0; i < 4; i++) drill.next().pitches],
        [ps('S R G P'), ps("P D S'"), ps("S' D P G"), ps('G R S')],
      );
      for (var i = 0; i < 50; i++) {
        expect(drill.next().pitches.length, lessThanOrEqualTo(4));
      }
      drill.maxNotes = 6;
      expect(drill.pool.map((d) => d.pitches.length).reduce(math.max), 6);
    });

    test('opens with the aaroh and avaroh, then never repeats back to back', () {
      final yaman = loadRagas().firstWhere((r) => r.id == 'yaman');
      final drill = RagaDrill(yaman, random: math.Random(1));
      expect(drill.next().label, 'Aaroh');
      expect(drill.next().label, 'Avaroh');
      Drill? last;
      final labels = <String>{};
      for (var i = 0; i < 100; i++) {
        final d = drill.next();
        expect(identical(d, last), isFalse);
        labels.add(d.label);
        last = d;
      }
      expect(labels, {'Aaroh', 'Avaroh', 'Pakad', 'Chalan'});
    });
  });
}
