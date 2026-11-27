import 'package:flutter_test/flutter_test.dart';
import 'package:aaroha/practice/practice_controller.dart';
import 'package:aaroha/practice/practice_settings.dart';
import 'package:aaroha/practice/session_summary.dart';
import 'package:aaroha_core/aaroha_core.dart';

Pitch p(String ascii) => parsePhrase(ascii).pitches.single;

NoteData note(String target, Verdict v, {String? played, double? dev}) =>
    NoteData(p(target), v, played == null ? null : p(played), dev);

void main() {
  test('practice settings survive a save and load', () {
    const s = PracticeSettings(
      mode: PracticeMode.phrase,
      swarSet: SwarSet.all,
      range: SaptakRange.withMandra,
      showTarget: ShowTarget.never,
      script: Script.devanagari,
      toleranceCents: 15,
      octaveMustMatch: false,
      rounds: 30,
      droneOn: false,
      droneVolume: 0.3,
      autoAdvance: false,
      saveSessionAudio: false,
      tuning: TuningChoice.equal,
      strictIntonation: true,
      missAction: MissAction.autoRetry,
      replayBeforeRetry: false,
      giveUpAfter: 5,
      missReveal: MissReveal.hint,
      answerBy: AnswerBy.name,
    );
    final back = PracticeSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('new defaults: just intonation, ear-first verdicts', () {
    const s = PracticeSettings();
    expect(s.tuning, TuningChoice.just);
    expect(s.strictIntonation, isFalse);
    final judge = s.judge(48000);
    expect(judge.tuning, Tuning.just);
    expect(judge.strictIntonation, isFalse);
    expect(s.answerBy, AnswerBy.play, reason: 'playing back stays the default');
  });

  test('a round passed with an out-of-tune note counts as a first-try pass', () {
    final r = RoundData(
      parsePhrase('N'),
      [
        [note('N', Verdict.outOfTune, played: 'N', dev: -30)],
      ],
      [true],
    );
    expect(r.firstTryPassed, isTrue);
    expect(SessionStats([r]).intonation[p('N')], -30);
  });

  group('after a miss (M2-A)', () {
    test('defaults wait for the player and give up after 3 misses', () {
      const s = PracticeSettings();
      expect(afterMiss(1, s), MissStep.wait);
      expect(afterMiss(2, s), MissStep.wait);
      expect(afterMiss(3, s), MissStep.giveUp);
    });

    test('auto-retry until the give-up limit', () {
      const s = PracticeSettings(missAction: MissAction.autoRetry, giveUpAfter: 2);
      expect(afterMiss(1, s), MissStep.autoRetry);
      expect(afterMiss(2, s), MissStep.giveUp);
    });

    test('never giving up keeps retrying', () {
      const s = PracticeSettings(missAction: MissAction.autoRetry, giveUpAfter: 0);
      expect(afterMiss(50, s), MissStep.autoRetry);
    });
  });

  group('pause', () {
    RoundRecord round() => RoundRecord(1, parsePhrase('S R G'));
    final judge = const PracticeSettings().judge(48000);
    final right = judgeNamed([p('S')], [p('S')], judge);
    final wrong = judgeNamed([p('S')], [p('R')], judge);

    test('only while a round is under way', () {
      for (final phase in PracticePhase.values) {
        expect(
          canPause(phase),
          const [
            PracticePhase.calling,
            PracticePhase.listening,
            PracticePhase.answering,
            PracticePhase.verdict,
          ].contains(phase),
          reason: phase.name,
        );
      }
    });

    test('resuming a round still being worked on plays its call again', () {
      expect(resumeStep(round()), ResumeStep.replayCall, reason: 'paused during the call');
      expect(resumeStep(round()..attempts.add(wrong)), ResumeStep.replayCall, reason: 'a miss');
    });

    test('resuming after a round is over moves on', () {
      expect(resumeStep(null), ResumeStep.nextRound);
      expect(resumeStep(round()..attempts.addAll([wrong, right])), ResumeStep.nextRound);
      expect(
        resumeStep(
          round()
            ..attempts.add(wrong)
            ..gaveUp = true,
        ),
        ResumeStep.nextRound,
      );
    });
  });

  test('old "show the notes" settings carry over', () {
    PracticeSettings load(String notation) => PracticeSettings.fromJson({'notation': notation});
    expect(load('shown').showTarget, ShowTarget.always);
    expect(load('afterAttempt').showTarget, ShowTarget.roundEnd);
    expect(load('hidden').showTarget, ShowTarget.never);
    // The old "after attempt" revealed the answer after a miss; it still does.
    expect(load('afterAttempt').missReveal, MissReveal.answer);
  });

  test('unknown or missing settings fall back to defaults', () {
    final s = PracticeSettings.fromJson({'mode': 'bogus', 'rounds': 10});
    expect(s.mode, PracticeMode.single);
    expect(s.rounds, 10);
    expect(s.toleranceCents, 25);
  });

  test('session stats: first-try accuracy, confusions, intonation', () {
    final rounds = [
      RoundData(
        parsePhrase('G'),
        [
          [note('G', Verdict.pass, played: 'G', dev: -10)],
        ],
        [true],
      ),
      RoundData(
        parsePhrase('G'),
        [
          [note('G', Verdict.wrongSwar, played: 'm', dev: 70)],
          [note('G', Verdict.pass, played: 'G', dev: -20)],
        ],
        [false, true],
      ),
      // Judged strictly (an older session): out of tune failed.
      RoundData(
        parsePhrase('m'),
        [
          [note('m', Verdict.outOfTune, played: 'm', dev: 40)],
        ],
        [false],
      ),
      RoundData(parsePhrase('P'), const [], const []),
    ];
    final stats = SessionStats(rounds);
    expect(stats.attempted.length, 3);
    expect(stats.firstTryAccuracy, closeTo(1 / 3, 1e-9));
    expect(stats.confusions, {(p('G'), p('m')): 1});
    expect(stats.intonation[p('G')], -10);
    expect(stats.intonation[p('m')], 40);
    expect(rounds[1].passedOnAttempt, 2);
  });

  test('rhythm: each target keeps its timing in the stored result, and the summary counts it', () {
    DetectedNote at(String swar, int onset) => DetectedNote(
      pitch: p(swar),
      onset: onset,
      end: onset + 40000,
      cents: Tuning.just.centsOf(p(swar)),
      deviation: 0,
      stability: 2,
    );
    const matra = 48000;
    final phrase = parsePhrase('S R G m');
    // R comes a quarter of a matra early; an extra P sneaks in after G.
    final result = judgePhrase(phrase.pitches, [
      at('S', 0),
      at('R', 36000),
      at('G', 96000),
      at('P', 120000),
      at('m', 144000),
    ], const JudgeSettings(tuning: Tuning.just));
    final timed = result.withRhythm(
      judgeRhythm(phrase, result, sams: const [0], matraFrames: matra.toDouble()),
    );
    final json = attemptToJson(timed);
    expect([for (final n in json) n['offset']], [0.0, -0.25, 0.0, null, 0.0]);
    final stats = SessionStats([
      RoundData(
        phrase,
        [
          [for (final n in json) NoteData.fromJson(n)],
        ],
        [timed.passed],
      ),
    ]);
    expect(stats.timing, (onTime: 3, early: 1, late: 0));
    expect(SessionStats([RoundData(phrase, const [], const [])]).timing, isNull);
  });
}
