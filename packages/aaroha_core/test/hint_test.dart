import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

DetectedNote played(double cents) {
  final nearest = Tuning.equal.nearest(cents);
  return DetectedNote(
    pitch: nearest.pitch,
    onset: 0,
    end: 48000,
    cents: cents,
    deviation: nearest.deviation,
    stability: 3,
  );
}

Pitch p(String ascii) => parsePhrase(ascii).pitches.single;

String hint(String target, double cents, {JudgeSettings settings = const JudgeSettings()}) {
  final judged = judgeSingle(p(target), [played(cents)], settings).notes.single;
  return hintText(hintFor(judged, settings.tuning));
}

void main() {
  test('in tune is right', () => expect(hint('G', 405), 'Right'));

  test('right swar, out of tune: a little flat or sharp', () {
    expect(hint('G', 365), 'Right note, a little flat');
    expect(hint('G', 435), 'Right note, a little sharp');
  });

  test('a wrong swar up to a whole tone away is too low or high', () {
    expect(hint('G', 300), 'Too low'); // komal Ga for Ga
    expect(hint('G', 500), 'Too high'); // Ma for Ga
    expect(hint('G', 200), 'Too low'); // Re for Ga
  });

  test('further away is much too low or high', () {
    expect(hint('G', 0), 'Much too low'); // Sa for Ga
    expect(hint('G', 700), 'Much too high'); // Pa for Ga
  });

  test('the right swar in another octave', () {
    expect(hint('N', -100), 'Right note, an octave too low');
    expect(hint('S', 1205), 'Right note, an octave too high');
  });

  test('hints never name a swar', () {
    final names = RegExp(r'\b(Sa|Re|Ga|Ma|Pa|Dha|Ni|komal|tivra|mandra|taar)\b');
    for (final cents in <double>[-700, -100, 0, 150, 300, 365, 500, 700, 1100, 1300]) {
      for (final target in ['S', 'R', 'G', 'm', 'P', 'D', 'N']) {
        expect(hint(target, cents), isNot(contains(names)));
      }
    }
  });

  test('phrase arrows point the way to move', () {
    final r = judgePhrase(parsePhrase('S R G').pitches, [
      played(0),
      played(100),
      played(500),
    ], const JudgeSettings());
    expect([for (final n in r.notes) hintArrow(hintFor(n, Tuning.equal))], ['✓', '↑', '↓']);
  });

  test('missing and extra notes in a phrase', () {
    final missing = judgePhrase(parsePhrase('S R G').pitches, [
      played(0),
      played(400),
    ], const JudgeSettings());
    expect(
      [for (final n in missing.notes) hintText(hintFor(n, Tuning.equal))],
      ['Right', 'A note is missing', 'Right'],
    );
    final extra = judgePhrase(parsePhrase('S G').pitches, [
      played(0),
      played(700),
      played(400),
    ], const JudgeSettings());
    expect(hintText(hintFor(extra.notes[1], Tuning.equal)), 'One note too many');
  });

  test('hints follow the session tuning', () {
    // 1072 c is 28 c below equal Ni but in tune with just Ni.
    expect(hint('N', 1072), 'Right note, a little flat');
    expect(hint('N', 1072, settings: const JudgeSettings(tuning: Tuning.just)), 'Right');
  });
}
