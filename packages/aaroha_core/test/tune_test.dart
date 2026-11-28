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

  group('timed tunes (D57)', () {
    test('start is a matra of the taal, counted from 1 at sam', () {
      final t = parseTune('x', 'taal: teentaal\nstart: 9\nG m P - | D P m G || S').tune!;
      expect([t.start, t.timed], [8, true]);
      expect(parseTune('x', 'taal: keherwa\nS R').tune!.start, 0);
      expect(parseTune('x', 'S R').tune!.timed, isFalse);
      expect(parseTune('x', 'start: 5\nS R').problems.single.message, contains('needs a taal'));
      expect(
        parseTune('x', 'taal: dadra\nstart: 7\nS R').problems.single.message,
        contains('1 to 6'),
      );
    });

    test('bars are checked against the taal from the start', () {
      // From matra 9 of teentaal: | before 13, || before sam.
      expect(parseTune('x', 'taal: teentaal\nstart: 9\nG m P - | D P m G || S').problems, isEmpty);
      final wrong = parseTune('x', 'taal: teentaal\nG m P | D P m G ||').problems;
      expect(wrong.map((p) => p.message), [
        contains('before matra 4; vibhags of Teentaal begin on 1, 5, 9, 13'),
        contains('"||" falls before matra 8'),
      ]);
      expect(wrong.first.line, 2);
    });

    test('a line is cut at vibhags, keeping each piece\'s place in the cycle', () {
      // Keherwa from matra 5 (khali): G m P - | D P m G || S - R G
      final line = parsePhrase('G m P - | D P m G || S - R G');
      final pieces = cutAtVibhags(line, Taal.keherwa, start: 4, maxNotes: 4);
      expect([for (final p in pieces) printNotation(p.phrase)], ['G m P -', 'D P m G', 'S - R G']);
      expect([for (final p in pieces) p.start], [4, 0, 4]);
      // Room for more: vibhags join while they fit.
      final two = cutAtVibhags(line, Taal.keherwa, start: 4, maxNotes: 7);
      expect([for (final p in two) p.start], [4, 4]);
      expect(two.first.phrase.pitches, hasLength(7));
    });

    test('never inside a held note, and leading silence is dropped', () {
      // The P is held across the vibhag, so the line can't be cut there.
      final held = cutAtVibhags(parsePhrase('S R G P | - - m G'), Taal.keherwa, maxNotes: 2);
      expect(held, hasLength(1));
      // A vibhag that starts with a rest: the piece starts on its first note.
      final rest = cutAtVibhags(parsePhrase('S R G m | _ _ P D'), Taal.keherwa, maxNotes: 4);
      expect([for (final p in rest) printNotation(p.phrase)], ['S R G m', 'P D']);
      expect(rest.last.start, 6, reason: 'P falls on matra 7');
    });

    test('the drill hands out each piece with its start', () {
      final tune = parseTune('x', 'taal: keherwa\nstart: 5\nG m P - | D P m G').tune!;
      final drill = TuneDrill(tune, maxNotes: 4);
      expect([drill.next().label, drill.lastStart], ['Line 1, part 1', 4]);
      expect([drill.next().label, drill.lastStart], ['Line 1, part 2', 0]);
      final untimed = TuneDrill(parseTune('x', 'S R G').tune!);
      untimed.next();
      expect(untimed.lastStart, 0);
    });
  });
}
