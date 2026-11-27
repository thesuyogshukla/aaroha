import 'dart:convert';

import 'package:aaroha/data/database.dart';
import 'package:aaroha/data/history.dart';
import 'package:aaroha/practice/practice_settings.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Pitch p(String ascii) => parsePhrase(ascii).pitches.single;

void main() {
  final at = DateTime(2026, 11, 22, 20);

  group('outcomeFromJson', () {
    test('rebuilds played cents in the session tuning', () {
      final note = {'target': 'N', 'verdict': 'outOfTune', 'played': 'N', 'deviation': -28.0};
      final equal = outcomeFromJson(note, tuning: Tuning.equal, at: at)!;
      expect(equal.cents, closeTo(1072, 1e-9));
      final just = outcomeFromJson(note, tuning: Tuning.just, at: at)!;
      expect(just.cents, closeTo(1088.27 - 28, 1e-9));
      expect(equal.rightSwar, isTrue);
    });

    test('a rhythm note keeps its timing', () {
      final note = {
        'target': 'R',
        'verdict': 'pass',
        'played': 'R',
        'deviation': 3.0,
        'offset': -0.2,
      };
      expect(outcomeFromJson(note, tuning: Tuning.just, at: at)!.offset, -0.2);
      expect(
        outcomeFromJson({'target': 'R', 'verdict': 'pass'}, tuning: Tuning.just, at: at)!.offset,
        isNull,
      );
    });

    test('named answers carry no intonation; extra notes are skipped', () {
      final named = outcomeFromJson(
        {'target': 'G', 'verdict': 'wrongSwar', 'played': 'm', 'deviation': 100.0},
        tuning: Tuning.just,
        at: at,
        named: true,
      )!;
      expect(named.cents, isNull);
      expect(named.played, p('m'));
      expect(
        outcomeFromJson(
          {'target': null, 'verdict': 'extra', 'played': 'P'},
          tuning: Tuning.equal,
          at: at,
        ),
        isNull,
      );
    });
  });

  test('loads first tries from every session', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final flute = (await db.select(db.flutes).get()).first; // seeded G medium

    Future<void> session(
      Map<String, Object?> settings,
      List<List<Map<String, Object?>>> attempts,
    ) async {
      final sid = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              fluteId: flute.id,
              mode: 'single',
              settingsJson: jsonEncode(settings),
              saHz: 393.8,
              startedAt: at,
            ),
          );
      final rid = await db
          .into(db.rounds)
          .insert(RoundsCompanion.insert(sessionId: sid, number: 1, target: 'N'));
      for (var i = 0; i < attempts.length; i++) {
        await db
            .into(db.attempts)
            .insert(
              AttemptsCompanion.insert(
                roundId: rid,
                number: i + 1,
                passed: false,
                resultJson: jsonEncode(attempts[i]),
                createdAt: at.add(Duration(seconds: i)),
              ),
            );
      }
      await (db.update(
        db.sessions,
      )..where((s) => s.id.equals(sid))).write(SessionsCompanion(endedAt: Value(at)));
    }

    // An old session (no tuning key: equal temperament), played.
    await session(
      {'mode': 'single'},
      [
        [
          {'target': 'N', 'verdict': 'outOfTune', 'played': 'N', 'deviation': -30.0},
        ],
        [
          {'target': 'N', 'verdict': 'outOfTune', 'played': 'N', 'deviation': -26.0},
        ],
      ],
    );
    // A named session in just intonation.
    await session(const PracticeSettings(answerBy: AnswerBy.name).toJson(), [
      [
        {'target': 'N', 'verdict': 'wrongSwar', 'played': 'D', 'deviation': -200.0},
      ],
    ]);

    final h = await loadPracticeHistory(db);
    final r = h.recordOf(p('N'));
    expect(r.tries, 2, reason: 'first tries only, one per session');
    expect(r.misses, 1);
    expect(h.confusions[(p('N'), p('D'))], 1);
    final intonation = h.intonation(Tuning.equal, fluteId: flute.id)[p('N')]!;
    expect(intonation.mean, closeTo(-30, 1e-9), reason: 'the named answer adds no intonation');
    expect(intonation.count, 1);
  });

  test('drilling is on by default and saved with the settings', () {
    expect(const PracticeSettings().adaptive, isTrue);
    final off = PracticeSettings.fromJson(const PracticeSettings(adaptive: false).toJson());
    expect(off.adaptive, isFalse);
  });
}
