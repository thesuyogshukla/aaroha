import 'package:drift/drift.dart' show OrderingTerm, BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../practice/practice_settings.dart';
import '../practice/session_summary.dart';

class _SessionRow {
  const _SessionRow(this.session, this.flute, this.rounds, this.firstTry);
  final Session session;
  final String flute;
  final int rounds;
  final int firstTry;
}

final _historyProvider = FutureProvider.autoDispose<List<_SessionRow>>((ref) async {
  final db = ref.watch(databaseProvider);
  final sessions = await (db.select(
    db.sessions,
  )..orderBy([(s) => OrderingTerm.desc(s.startedAt)])).get();
  final flutes = {for (final f in await db.select(db.flutes).get()) f.id: f.name};
  final out = <_SessionRow>[];
  for (final s in sessions) {
    final rounds = await (db.select(db.rounds)..where((r) => r.sessionId.equals(s.id))).get();
    var attempted = 0, firstTry = 0;
    for (final r in rounds) {
      final first = await (db.select(
        db.attempts,
      )..where((a) => a.roundId.equals(r.id) & a.number.equals(1))).getSingleOrNull();
      if (first == null) continue;
      attempted++;
      if (first.passed) firstTry++;
    }
    if (attempted > 0) out.add(_SessionRow(s, flutes[s.fluteId] ?? '?', attempted, firstTry));
  }
  return out;
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No sessions yet.'))
            : ListView(
                children: [
                  for (final r in rows)
                    ListTile(
                      title: Text('${r.flute} · ${sessionLabel(r.session.settingsJson)}'),
                      subtitle: Text(_date(r.session.startedAt)),
                      trailing: Text(
                        '${(100 * r.firstTry / r.rounds).round()}% · ${r.rounds} '
                        '${r.rounds == 1 ? 'round' : 'rounds'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SessionSummaryScreen(session: r.session, flute: r.flute),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

String _date(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
