import 'dart:math' as math;

import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

Fraction f(int n, [int d = 1]) => Fraction(n, d);

String shape(Phrase p) =>
    p.notes.map((n) => '${n.pitch?.ascii ?? '_'}@${n.start}+${n.duration}').join(' ');

void main() {
  group('Fraction', () {
    test('normalises and compares', () {
      expect(Fraction(2, 4), Fraction(1, 2));
      expect(Fraction(1, -3), Fraction(-1, 3));
      expect(Fraction(1, 3) + Fraction(1, 6), Fraction(1, 2));
      expect(Fraction(7, 2).floor(), 3);
      expect(Fraction(-1, 2).floor(), -1);
      expect(Fraction(1, 3) < Fraction(1, 2), isTrue);
    });
  });

  group('parse', () {
    test('one note per matra', () {
      final p = parsePhrase('S R G m');
      expect(shape(p), 'S@0+1 R@1+1 G@2+1 m@3+1');
    });

    test('octave marks, komal and tivra', () {
      final p = parsePhrase(".N r g M d' n'");
      expect(p.pitches.map((x) => x.ascii), ['.N', 'r', 'g', 'M', "d'", "n'"]);
      expect(p.pitches.first, const Pitch(Swar.ni, -1));
      expect(p.pitches[3].swar, Swar.tivraMa);
    });

    test('positions inside a matra share it equally', () {
      expect(shape(parsePhrase('SR G')), 'S@0+1/2 R@1/2+1/2 G@1+1');
      expect(shape(parsePhrase('SRG')), 'S@0+1/3 R@1/3+1/3 G@2/3+1/3');
      expect(shape(parsePhrase('S-R')), 'S@0+2/3 R@2/3+1/3');
      expect(shape(parsePhrase('.N.D')), '.N@0+1/2 .D@1/2+1/2');
    });

    test('holds extend across matras', () {
      expect(shape(parsePhrase('S - R -')), 'S@0+2 R@2+2');
    });

    test('rests merge', () {
      expect(shape(parsePhrase('S _ _ R')), 'S@0+1 _@1+2 R@3+1');
      expect(shape(parsePhrase('S _ - R')), 'S@0+1 _@1+2 R@3+1');
    });

    test('bars and phrase breaks', () {
      final p = parsePhrase('S R | G m || P , D');
      expect(p.bars, [Bar(f(2)), Bar(f(4), avartanEnd: true)]);
      expect([for (final n in p.notes) n.breakBefore], [false, false, false, false, false, true]);
    });

    test('kan and meend', () {
      final p = parsePhrase('{N}S G~R');
      expect(p.notes[0].kan, const Pitch(Swar.ni));
      expect(p.notes[0].pitch, const Pitch(Swar.sa));
      expect(p.notes[1].glideToNext, isTrue);
      expect(shape(p), 'S@0+1 G@1+1/2 R@3/2+1/2');
      expect(parsePhrase('G-~R').notes.first.glideToNext, isTrue);
    });

    test('header, separator and comments', () {
      final p = parsePhrase('''
title: Yaman — pakad
raga: yaman
taal: keherwa
tempo: 80
---
.N R G R | S .N R S ||   # pakad
''');
      expect(p.title, 'Yaman — pakad');
      expect(p.taal, Taal.keherwa);
      expect(p.tempo, 80);
      expect(p.pitches.length, 8);
    });

    test('docs/03 examples parse', () {
      for (final text in [
        "S R G m P D N S'",
        "S R G P D S' , S' D P G R S",
        'G m d - , d P , G m r - , r S',
        'S - RG m | P - DP mG ||',
      ]) {
        expect(parseNotation(text).ok, isTrue, reason: text);
      }
    });
  });

  group('errors', () {
    List<String> errorsOf(String text) => [for (final e in parseNotation(text).errors) e.message];

    test('unknown characters, with position', () {
      final r = parseNotation('S R\nG x');
      expect(r.ok, isFalse);
      expect(r.errors.single.line, 2);
      expect(r.errors.single.column, 3);
    });

    test('hold with nothing to hold', () {
      expect(errorsOf('- S'), [contains('no note comes before')]);
    });

    test('mandra and taar together', () {
      expect(errorsOf(".S'"), [contains('both mandra and taar')]);
    });

    test('bad kan and meend', () {
      expect(errorsOf('{NR}S'), [contains('exactly one swar')]);
      expect(errorsOf('{N}-'), [contains('right before a note')]);
      expect(errorsOf('G~ R'), [contains('needs a note after it')]);
      expect(errorsOf('_~S'), [contains('must follow a note')]);
    });

    test('taal length and vibhags are checked', () {
      expect(errorsOf('taal: keherwa\n---\nS R G m | P D N ||'), [contains('has 7 matras')]);
      expect(errorsOf('taal: keherwa\n---\nS R G | m P D N S ||'), [
        contains('vibhag bar after matra 3'),
      ]);
      expect(errorsOf('taal: dadra\n---\nS R G | m P D ||'), isEmpty);
      expect(errorsOf('taal: bogus\n---\nS'), [contains('unknown taal')]);
    });

    test('a break before a hold', () {
      expect(errorsOf('S , - R'), [contains("can't be followed by a hold")]);
    });
  });

  group('print', () {
    test('canonical form', () {
      expect(printNotation(parsePhrase('S  -  RG  m  |  P')), 'S - RG m | P');
      expect(printNotation(parsePhrase('S-R _-')), 'S-R _');
      expect(printNotation(parsePhrase('S R , G')), 'S R , G');
    });

    test('header comes first', () {
      expect(
        printNotation(parsePhrase('taal: dadra\n---\nS R G | m P D ||')),
        'taal: dadra\n---\nS R G | m P D ||',
      );
    });

    test('round trip on random notation', () {
      final rng = math.Random(7);
      const swars = 'SrRgGmMPdDnN';
      String pitch() {
        final octave = rng.nextInt(3) - 1;
        return '${octave < 0 ? '.' : ''}${swars[rng.nextInt(12)]}${octave > 0 ? "'" : ''}';
      }

      for (var trial = 0; trial < 300; trial++) {
        final tokens = <String>[];
        for (var m = 0; m < 1 + rng.nextInt(8); m++) {
          if (m > 0 && rng.nextInt(6) == 0) tokens.add(rng.nextBool() ? '|' : ',');
          final positions = 1 + rng.nextInt(4);
          final b = StringBuffer();
          for (var p = 0; p < positions; p++) {
            final r = rng.nextInt(10);
            final first = m == 0 && p == 0;
            final afterBreak = p == 0 && tokens.isNotEmpty && tokens.last == ',';
            if (r < 2 && !first && !afterBreak) {
              b.write('-');
            } else if (r < 3) {
              b.write('_');
            } else if (r < 4) {
              b.write('{${pitch()}}${pitch()}');
            } else {
              b.write(pitch());
            }
            if (p + 1 < positions &&
                rng.nextInt(8) == 0 &&
                RegExp(r"[A-Za-z'\-]$").hasMatch(b.toString())) {
              b.write('~');
            }
          }
          tokens.add(b.toString());
        }
        final text = tokens.join(' ');
        final parsed = parseNotation(text);
        if (!parsed.ok) continue; // e.g. a meend into a rest
        final printed = printNotation(parsed.phrase!);
        expect(parsePhrase(printed), parsed.phrase, reason: '$text -> $printed');
      }
    });
  });
}
