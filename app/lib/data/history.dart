import 'dart:convert';

import 'package:aaroha_core/aaroha_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';

/// Turns one stored note verdict (Attempts.resultJson) into a history entry.
/// Played cents are rebuilt from the deviation in the session's own tuning,
/// so sessions in different tunings line up.
NoteOutcome? outcomeFromJson(
  Map<String, Object?> note, {
  required Tuning tuning,
  required DateTime at,
  int? fluteId,
  bool named = false,
}) {
  final target = note['target'] as String?;
  if (target == null) return null; // an extra note: no target to learn about
  final targetPitch = parsePhrase(target).pitches.single;
  final played = note['played'] as String?;
  final deviation = (note['deviation'] as num?)?.toDouble();
  return NoteOutcome(
    target: targetPitch,
    verdict: Verdict.values.byName(note['verdict'] as String),
    at: at,
    played: played == null ? null : parsePhrase(played).pitches.single,
    // Tapped answers are exact, so they say nothing about intonation.
    cents: named || deviation == null ? null : tuning.centsOf(targetPitch) + deviation,
    fluteId: fluteId,
    named: named,
    offset: (note['offset'] as num?)?.toDouble(),
  );
}

/// Every stored first try, across sessions (docs/05 §7).
Future<PracticeHistory> loadPracticeHistory(AppDatabase db) async {
  final query = db.select(db.attempts).join([
    innerJoin(db.rounds, db.rounds.id.equalsExp(db.attempts.roundId)),
    innerJoin(db.sessions, db.sessions.id.equalsExp(db.rounds.sessionId)),
  ])..where(db.attempts.number.equals(1));
  final history = PracticeHistory();
  for (final row in await query.get()) {
    final attempt = row.readTable(db.attempts);
    final session = row.readTable(db.sessions);
    final settings = jsonDecode(session.settingsJson) as Map<String, dynamic>;
    // Sessions before D31 have no tuning: they were equal temperament.
    final tuning = settings['tuning'] == 'just' ? Tuning.just : Tuning.equal;
    final named = settings['answerBy'] == 'name';
    for (final note in jsonDecode(attempt.resultJson) as List) {
      final o = outcomeFromJson(
        (note as Map).cast<String, Object?>(),
        tuning: tuning,
        at: attempt.createdAt,
        fluteId: session.fluteId,
        named: named,
      );
      if (o != null) history.add(o);
    }
  }
  return history;
}

final practiceHistoryProvider = FutureProvider.autoDispose<PracticeHistory>(
  (ref) => loadPracticeHistory(ref.watch(databaseProvider)),
);
