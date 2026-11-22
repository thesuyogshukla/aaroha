import 'package:flutter_test/flutter_test.dart';
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
      notation: NotationDisplay.hidden,
      script: Script.devanagari,
      toleranceCents: 15,
      octaveMustMatch: false,
      rounds: 30,
      droneOn: false,
      droneVolume: 0.3,
      autoAdvance: false,
    );
    final back = PracticeSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('unknown or missing settings fall back to defaults', () {
    final s = PracticeSettings.fromJson({'mode': 'bogus', 'rounds': 10});
    expect(s.mode, PracticeMode.single);
    expect(s.rounds, 10);
    expect(s.toleranceCents, 25);
  });

  test('session stats: first-try accuracy, confusions, intonation', () {
    final rounds = [
      RoundData([p('G')], [
        [note('G', Verdict.pass, played: 'G', dev: -10)],
      ]),
      RoundData([p('G')], [
        [note('G', Verdict.wrongSwar, played: 'm', dev: 70)],
        [note('G', Verdict.pass, played: 'G', dev: -20)],
      ]),
      RoundData([p('m')], [
        [note('m', Verdict.outOfTune, played: 'm', dev: 40)],
      ]),
      RoundData([p('P')], const []),
    ];
    final stats = SessionStats(rounds);
    expect(stats.attempted.length, 3);
    expect(stats.firstTryAccuracy, closeTo(1 / 3, 1e-9));
    expect(stats.confusions, {(p('G'), p('m')): 1});
    expect(stats.intonation[p('G')], -10);
    expect(stats.intonation[p('m')], 40);
    expect(rounds[1].passedOnAttempt, 2);
  });
}
