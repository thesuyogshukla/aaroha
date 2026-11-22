import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

List<Pitch> ps(String notation) => parsePhrase(notation).pitches;

String verdicts(AttemptResult r) => r.notes.map((n) => n.verdict.name).join(' ');

void main() {
  const settings = JudgeSettings();

  test('right answers pass, in tune by definition', () {
    final r = judgeNamed(ps('S R G'), ps('S R G'), settings);
    expect(verdicts(r), 'pass pass pass');
    expect(r.passed, isTrue);
    expect(r.inTune, isTrue);
  });

  test('a neighbouring swar is a wrong swar, with a hint that never names it', () {
    final r = judgeNamed(ps('G'), ps('m'), settings);
    expect(verdicts(r), 'wrongSwar');
    expect(r.passed, isFalse);
    expect(hintText(hintFor(r.notes.single, Tuning.equal)), 'Too high');
    final komal = judgeNamed(ps('G'), ps('g'), settings);
    expect(hintText(hintFor(komal.notes.single, Tuning.equal)), 'Too low');
  });

  test('octaves count only when the octave must match', () {
    expect(verdicts(judgeNamed(ps('N'), ps('.N'), settings)), 'wrongOctave');
    const loose = JudgeSettings(octaveMustMatch: false);
    expect(verdicts(judgeNamed(ps('N'), ps('.N'), loose)), 'pass');
  });

  test('a phrase answered part way: the rest is missing', () {
    expect(verdicts(judgeNamed(ps('S R G m'), ps('S R'), settings)), 'pass pass missing missing');
  });

  test('extra taps are extra notes', () {
    expect(verdicts(judgeNamed(ps('S R'), ps('S R G'), settings)), 'pass pass extra');
  });

  test('works in just intonation too', () {
    const just = JudgeSettings(tuning: Tuning.just);
    expect(verdicts(judgeNamed(ps('N D'), ps('N D'), just)), 'pass pass');
  });
}
