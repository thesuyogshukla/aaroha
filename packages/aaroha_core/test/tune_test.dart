import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

String text(Phrase p) => printNotation(p);

void main() {
  group('parseTune', () {
    test('a header, then one line of the tune per row; blanks and comments skipped', () {
      final r = parseTune(' Evening tune ', '''
taal: teentaal
tempo: 80
---
# sthayi
S - R G | m - G R

G m P - , P m G R   # second line
''');
      expect(r.problems, isEmpty);
      final tune = r.tune!;
      expect(tune.title, 'Evening tune');
      expect(tune.taal, Taal.teentaal);
      expect(tune.header['tempo'], '80');
      expect([for (final l in tune.lines) text(l)], ['S - R G | m - G R', 'G m P - , P m G R']);
      expect(tune.noteCount, 13);
    });

    test('the header and its --- are optional', () {
      expect(parseTune('x', 'S R G').tune!.lines, hasLength(1));
      expect(parseTune('x', 'taal: dadra\nS R G | m - -').tune!.taal, Taal.dadra);
    });

    test('problems name the line as typed', () {
      final r = parseTune('x', 'taal: teentaal\n\nS R G\nS X G\n_ _ |\n');
      expect(r.tune, isNull);
      expect([for (final p in r.problems) p.line], [4, 5]);
      expect(r.problems.first.column, 3);
      expect(r.problems.last.message, contains('no notes'));
    });

    test('an unknown taal, a bad tempo, no title or no lines are problems', () {
      expect(parseTune('x', 'taal: bogus\nS R').problems.single.message, contains('taal'));
      expect(parseTune('x', 'tempo: fast\nS R').problems.single.message, contains('tempo'));
      expect(parseTune(' ', 'S R').problems.single.message, contains('title'));
      expect(parseTune('x', '# nothing yet\n').problems.single.message, contains('line'));
    });
  });

  test('lines with notes beyond the flute are found', () {
    final tune = parseTune('x', "S R G\nP D N S' R'\n.D .N S").tune!;
    expect(linesOutOfRange(tune, low: const Pitch(Swar.pa, -1), high: const Pitch(Swar.pa, 1)), []);
    expect(linesOutOfRange(tune, low: const Pitch(Swar.sa), high: const Pitch(Swar.sa, 1)), [2, 3]);
  });

  group('TuneDrill', () {
    final tune = parseTune('x', "S R G m\nP D N S' R' G'\nm G R S").tune!;

    test('plays the lines in order, again and again, cutting long ones', () {
      final drill = TuneDrill(tune, maxNotes: 4);
      final labels = [for (var i = 0; i < 6; i++) drill.next().label];
      expect(labels, [
        'Line 1',
        'Line 2, part 1',
        'Line 2, part 2',
        'Line 3',
        'Line 1',
        'Line 2, part 1',
      ]);
    });

    test('leaves out lines the flute can\'t play', () {
      final drill = TuneDrill(tune, high: const Pitch(Swar.sa, 1), maxNotes: 8);
      expect(drill.playableLines, 2);
      expect(
        [drill.next().label, drill.next().label, drill.next().label],
        ['Line 1', 'Line 3', 'Line 1'],
      );
      expect(
        () => TuneDrill(parseTune('x', "R' G'").tune!, high: const Pitch(Swar.sa, 1)),
        throwsArgumentError,
      );
    });

    test('a new length starts again from the line being practised', () {
      final drill = TuneDrill(tune, maxNotes: 8);
      drill.next();
      expect(drill.next().label, 'Line 2');
      drill.maxNotes = 4;
      expect(drill.next().label, 'Line 2, part 1');
      expect(drill.next().label, 'Line 2, part 2');
    });
  });
}
