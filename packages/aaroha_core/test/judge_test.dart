import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

/// A detected note at [cents] from Sa lasting [ms].
DetectedNote played(double cents, {int ms = 600, int at = 0}) {
  final nearest = Tuning.equal.nearest(cents);
  return DetectedNote(
    pitch: nearest.pitch,
    onset: at,
    end: at + ms * 48,
    cents: cents,
    deviation: nearest.deviation,
    stability: 3,
  );
}

Pitch p(String ascii) => parsePhrase(ascii).pitches.single;

List<Pitch> ps(String notation) => parsePhrase(notation).pitches;

String verdicts(AttemptResult r) => r.notes.map((n) => n.verdict.name).join(' ');

void main() {
  const settings = JudgeSettings();

  group('single swar', () {
    test('pass, out of tune, wrong swar (docs/05)', () {
      expect(verdicts(judgeSingle(p('G'), [played(410)], settings)), 'pass');
      expect(verdicts(judgeSingle(p('G'), [played(368)], settings)), 'outOfTune');
      // 60 c flat of Ga is komal Ga territory: a different swar.
      final wrong = judgeSingle(p('G'), [played(340)], settings);
      expect(verdicts(wrong), 'wrongSwar');
      expect(wrong.notes.single.played!.pitch, p('g'));
      expect(wrong.notes.single.deviation, closeTo(-60, 1e-9));
    });

    test('wrong octave unless octave matching is off', () {
      expect(verdicts(judgeSingle(p('G'), [played(1605)], settings)), 'wrongOctave');
      final loose = judgeSingle(p('G'), [
        played(1605),
      ], const JudgeSettings(octaveMustMatch: false));
      expect(verdicts(loose), 'pass');
      expect(loose.notes.single.deviation, closeTo(5, 1e-9));
    });

    test('short blips before the real note are skipped', () {
      final r = judgeSingle(p('P'), [played(500, ms: 150), played(705, ms: 800)], settings);
      expect(verdicts(r), 'pass');
    });

    test('nothing long enough is missing', () {
      expect(verdicts(judgeSingle(p('S'), [played(0, ms: 200)], settings)), 'missing');
      expect(verdicts(judgeSingle(p('S'), const [], settings)), 'missing');
    });

    test('tolerance is a setting', () {
      const strict = JudgeSettings(toleranceCents: 10);
      expect(verdicts(judgeSingle(p('R'), [played(215)], strict)), 'outOfTune');
    });
  });

  group('phrase', () {
    test('all notes right', () {
      final r = judgePhrase(ps('S R G m'), [
        played(0),
        played(205),
        played(390),
        played(498),
      ], settings);
      expect(r.passed, isTrue);
      expect(verdicts(r), 'pass pass pass pass');
    });

    test('one note out of tune is shown on that note', () {
      final r = judgePhrase(ps('S R G'), [played(0), played(240), played(400)], settings);
      expect(r.passed, isFalse);
      expect(verdicts(r), 'pass outOfTune pass');
    });

    test('a wrong swar in the middle', () {
      final r = judgePhrase(ps('S R G'), [played(0), played(300), played(400)], settings);
      expect(verdicts(r), 'pass wrongSwar pass');
    });

    test('missing and extra notes', () {
      expect(
        verdicts(judgePhrase(ps('S R G'), [played(0), played(400)], settings)),
        'pass missing pass',
      );
      expect(
        verdicts(judgePhrase(ps('S G'), [played(0), played(700), played(400)], settings)),
        'pass extra pass',
      );
    });

    test('a note split by a breath counts once', () {
      final r = judgePhrase(ps('S R'), [played(0), played(2), played(200)], settings);
      expect(verdicts(r), 'pass pass');
    });

    test('repeated targets keep repeated notes', () {
      final r = judgePhrase(ps('S S R'), [played(0), played(2), played(200)], settings);
      expect(verdicts(r), 'pass pass pass');
      final short = judgePhrase(ps('S S R'), [played(0), played(200)], settings);
      expect(verdicts(short), 'pass missing pass');
    });

    test('the owner\'s sharp Ma reads as a wrong swar in a phrase', () {
      // From fixtures/g-medium/phrases: shuddha Ma played ~70 c sharp.
      final r = judgePhrase(ps('S R G m P'), [
        played(-7),
        played(185),
        played(365),
        played(570),
        played(685),
      ], settings);
      expect(verdicts(r), 'pass pass outOfTune wrongSwar pass');
    });
  });
}
