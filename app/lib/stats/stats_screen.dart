import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history.dart';
import '../data/providers.dart';
import '../practice/practice_settings.dart';
import '../widgets/sargam.dart';

/// Smart-drilling stats (docs/05 §7): right first time per swar, which swars
/// are heard as which, and intonation on the selected flute. Each swar's most
/// recent first tries count, from both playing and naming.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(practiceHistoryProvider);
    final settings = ref.watch(practiceSettingsProvider).value ?? const PracticeSettings();
    final flute = ref.watch(selectedFluteProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your ear')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (h) => h.targets.isEmpty
            ? const Center(child: Text('Practise a few rounds and your stats appear here.'))
            : _StatsView(
                history: h,
                settings: settings,
                fluteId: flute?.id,
                fluteName: flute?.name,
              ),
      ),
    );
  }
}

/// Which way the player's timing leans, from the middle offset (matras).
String _lean(double median) {
  final pct = (100 * median.abs()).round();
  if (pct < 5) return 'You come in right on the beat, on the whole.';
  return 'On the whole you come in a little ${median < 0 ? 'early' : 'late'}, '
      'by about $pct% of a matra.';
}

class _StatsView extends StatelessWidget {
  const _StatsView({
    required this.history,
    required this.settings,
    required this.fluteId,
    required this.fluteName,
  });

  final PracticeHistory history;
  final PracticeSettings settings;
  final int? fluteId;
  final String? fluteName;

  List<Pitch> _sorted(Iterable<Pitch> pitches) =>
      pitches.toList()..sort((a, b) => Tuning.equal.centsOf(a).compareTo(Tuning.equal.centsOf(b)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final script = settings.script;
    final targets = _sorted(history.targets);
    final confusions = history.confusions;
    final intonation = history.intonation(settings.tuning.tuning, fluteId: fluteId);
    final timing = history.timing();

    Widget heading(String text, String note) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleMedium),
          Text(note, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        heading(
          'Right first time',
          'Each swar\'s last ${history.window} first tries, playing and naming. '
              'The ones you miss come up more often.',
        ),
        for (final p in targets)
          _AccuracyRow(pitch: p, record: history.recordOf(p), script: script),
        heading('Heard as', 'Row: the swar played to you. Column: what you answered.'),
        if (confusions.isEmpty)
          const Text('No mix-ups recently.')
        else
          _ConfusionGrid(confusions: confusions, script: script, sorted: _sorted),
        heading(
          'Intonation${fluteName == null ? '' : ' on $fluteName'}',
          'Average cents from the target (${settings.tuning.label.toLowerCase()} intonation), '
              'when you played the right swar.',
        ),
        if (intonation.isEmpty)
          const Text('No flute practice on this flute yet.')
        else
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final p in _sorted(intonation.keys))
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwarGlyph(p, script: script, size: 24),
                    Text(
                      '${intonation[p]!.mean >= 0 ? '+' : '−'}${intonation[p]!.mean.abs().round()} c',
                      style: TextStyle(
                        color: intonation[p]!.mean.abs() <= 15
                            ? theme.colorScheme.primary
                            : theme.colorScheme.tertiary,
                      ),
                    ),
                    Text('${intonation[p]!.count}×', style: theme.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        if (timing != null) ...[
          heading(
            'Timing',
            'Your last ${timing.count} timed notes in Rhythm practice, first tries. '
                'On time is within ${(100 * const RhythmSettings().tolerance).round()}% of a matra.',
          ),
          Text(
            '${(100 * timing.onTimeShare).round()}% on time · ${timing.early} early · '
            '${timing.late} late',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(_lean(timing.medianOffset), style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  const _AccuracyRow({required this.pitch, required this.record, required this.script});
  final Pitch pitch;
  final SwarRecord record;
  final Script script;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = record.accuracy ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(child: SwarGlyph(pitch, script: script, size: 20)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: accuracy,
                minHeight: 12,
                color: accuracy >= 0.8
                    ? theme.colorScheme.primary
                    : accuracy >= 0.5
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              '${(accuracy * 100).round()}% · ${record.tries}',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfusionGrid extends StatelessWidget {
  const _ConfusionGrid({required this.confusions, required this.script, required this.sorted});
  final Map<(Pitch, Pitch), int> confusions;
  final Script script;
  final List<Pitch> Function(Iterable<Pitch>) sorted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = sorted({for (final k in confusions.keys) k.$1});
    final cols = sorted({for (final k in confusions.keys) k.$2});
    final most = confusions.values.reduce((a, b) => a > b ? a : b);
    const cell = 40.0;
    // Labels take the same space as a cell, margin included, so each one
    // sits centred over its column and beside its row.
    const margin = EdgeInsets.all(1);
    Widget glyph(Pitch p) => Container(
      width: cell,
      height: cell,
      margin: margin,
      alignment: Alignment.center,
      child: SwarGlyph(p, script: script, size: 16),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: cell + 2),
              for (final c in cols) glyph(c),
            ],
          ),
          for (final r in rows)
            Row(
              children: [
                glyph(r),
                for (final c in cols)
                  Container(
                    width: cell,
                    height: cell,
                    margin: margin,
                    decoration: BoxDecoration(
                      color: confusions[(r, c)] == null
                          ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                          : scheme.error.withValues(alpha: 0.2 + 0.6 * confusions[(r, c)]! / most),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        confusions[(r, c)]?.toString() ?? '',
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
