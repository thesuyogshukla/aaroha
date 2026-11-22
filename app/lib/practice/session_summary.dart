import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../widgets/sargam.dart';
import 'practice_settings.dart';

/// One judged note, as stored in Attempts.resultJson.
class NoteData {
  const NoteData(this.target, this.verdict, this.played, this.deviation);

  factory NoteData.fromJson(Map<String, Object?> j) => NoteData(
    _pitch(j['target'] as String?),
    Verdict.values.byName(j['verdict'] as String),
    _pitch(j['played'] as String?),
    (j['deviation'] as num?)?.toDouble(),
  );

  final Pitch? target;
  final Verdict verdict;
  final Pitch? played;
  final double? deviation;

  static Pitch? _pitch(String? ascii) => ascii == null ? null : parsePhrase(ascii).pitches.single;
}

class RoundData {
  const RoundData(this.target, this.attempts, this.passed);
  final List<Pitch> target;

  /// Whether each attempt passed, as decided when it was judged (with the
  /// session's own strict-intonation setting, D31).
  final List<bool> passed;
  final List<List<NoteData>> attempts;

  bool get firstTryPassed => passed.isNotEmpty && passed.first;
  int? get passedOnAttempt {
    for (var i = 0; i < attempts.length; i++) {
      if (passed[i]) return i + 1;
    }
    return null;
  }
}

/// Figures shown at the end of a session and in history (docs/05 §7).
class SessionStats {
  SessionStats(this.rounds);
  final List<RoundData> rounds;

  List<RoundData> get attempted => [
    for (final r in rounds)
      if (r.attempts.isNotEmpty) r,
  ];

  double? get firstTryAccuracy =>
      attempted.isEmpty ? null : attempted.where((r) => r.firstTryPassed).length / attempted.length;

  /// Wrong swars on first attempts: target → played → count.
  Map<(Pitch, Pitch), int> get confusions {
    final out = <(Pitch, Pitch), int>{};
    for (final r in attempted) {
      for (final n in r.attempts.first) {
        if ((n.verdict == Verdict.wrongSwar || n.verdict == Verdict.wrongOctave) &&
            n.target != null &&
            n.played != null) {
          out.update((n.target!, n.played!), (c) => c + 1, ifAbsent: () => 1);
        }
      }
    }
    return out;
  }

  /// Mean deviation per target swar, over first-attempt notes that were the
  /// right swar (in tune or not).
  Map<Pitch, double> get intonation {
    final sums = <Pitch, List<double>>{};
    for (final r in attempted) {
      for (final n in r.attempts.first) {
        if ((n.verdict == Verdict.pass || n.verdict == Verdict.outOfTune) &&
            n.target != null &&
            n.deviation != null) {
          sums.putIfAbsent(n.target!, () => []).add(n.deviation!);
        }
      }
    }
    return {for (final e in sums.entries) e.key: e.value.reduce((a, b) => a + b) / e.value.length};
  }
}

/// Loads a stored session's rounds and attempts.
final sessionRoundsProvider = FutureProvider.family<List<RoundData>, int>((ref, sessionId) async {
  final db = ref.watch(databaseProvider);
  final rounds =
      await (db.select(db.rounds)
            ..where((r) => r.sessionId.equals(sessionId))
            ..orderBy([(r) => OrderingTerm.asc(r.number)]))
          .get();
  final out = <RoundData>[];
  for (final r in rounds) {
    final attempts =
        await (db.select(db.attempts)
              ..where((a) => a.roundId.equals(r.id))
              ..orderBy([(a) => OrderingTerm.asc(a.number)]))
            .get();
    out.add(
      RoundData(
        parsePhrase(r.target).pitches,
        [
          for (final a in attempts)
            [
              for (final n in jsonDecode(a.resultJson) as List)
                NoteData.fromJson((n as Map).cast<String, Object?>()),
            ],
        ],
        [for (final a in attempts) a.passed],
      ),
    );
  }
  return out;
});

class SessionSummaryView extends StatelessWidget {
  const SessionSummaryView({super.key, required this.rounds, required this.script});
  final List<RoundData> rounds;
  final Script script;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = SessionStats(rounds);
    final accuracy = stats.firstTryAccuracy;
    final confusions = stats.confusions.entries.toList()..sort((a, b) => b.value - a.value);
    final intonation = stats.intonation.entries.toList()
      ..sort((a, b) => Tuning.equal.centsOf(a.key).compareTo(Tuning.equal.centsOf(b.key)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                accuracy == null ? '–' : '${(accuracy * 100).round()}%',
                style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                'right first time · ${stats.attempted.length} rounds',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        if (confusions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Swars you mixed up (first tries)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final c in confusions)
            ListTile(
              dense: true,
              leading: SizedBox(width: 40, child: SwarGlyph(c.key.$1, script: script, size: 22)),
              title: Row(
                children: [
                  const Text('played as  '),
                  SwarGlyph(c.key.$2, script: script, size: 22),
                ],
              ),
              trailing: Text('×${c.value}'),
            ),
        ],
        if (intonation.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Average intonation (right swar)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final e in intonation)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwarGlyph(e.key, script: script, size: 24),
                    Text(
                      '${e.value >= 0 ? '+' : '−'}${e.value.abs().round()} c',
                      style: TextStyle(
                        color: e.value.abs() <= 15
                            ? theme.colorScheme.primary
                            : theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Rounds', style: theme.textTheme.titleMedium),
        for (var i = 0; i < rounds.length; i++)
          ListTile(
            dense: true,
            leading: Text('${i + 1}'),
            title: Align(
              alignment: Alignment.centerLeft,
              child: SargamRow(rounds[i].target, script: script, size: 20),
            ),
            trailing: Text(_roundOutcome(rounds[i])),
          ),
      ],
    );
  }

  static String _roundOutcome(RoundData r) {
    if (r.attempts.isEmpty) return 'skipped';
    final passed = r.passedOnAttempt;
    if (passed == 1) return '✓ first try';
    if (passed != null) return '✓ on try $passed';
    return '✗ ${r.attempts.length} ${r.attempts.length == 1 ? 'try' : 'tries'}';
  }
}

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key, required this.session, required this.flute});
  final Session session;
  final String flute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rounds = ref.watch(sessionRoundsProvider(session.id));
    final settings = PracticeSettings.fromJson(
      (jsonDecode(session.settingsJson) as Map).cast<String, dynamic>(),
    );
    return Scaffold(
      appBar: AppBar(title: Text('$flute · ${_date(session.startedAt)}')),
      body: rounds.when(
        data: (r) => SessionSummaryView(rounds: r, script: settings.script),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

String _date(DateTime d) => '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
