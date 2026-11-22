import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../debug/debug_screen.dart';
import '../flutes/calibration_sheet.dart';
import '../flutes/flutes_screen.dart';
import '../practice/practice_controller.dart';
import '../practice/practice_screen.dart';
import '../practice/practice_settings.dart';
import 'history_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flute = ref.watch(selectedFluteProvider);
    final settings = ref.watch(practiceSettingsProvider).value;
    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aaroha'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => open(const HistoryScreen()),
          ),
          IconButton(
            tooltip: 'Test tools',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => open(const DebugScreen()),
          ),
        ],
      ),
      body: flute == null || settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FluteCard(flute: flute, onChange: () => open(const FlutesScreen())),
                const SizedBox(height: 16),
                _Options(settings: settings),
              ],
            ),
      bottomNavigationBar: flute == null || settings == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Start · ${settings.rounds} rounds'),
                  onPressed: () {
                    ref.read(practiceProvider.notifier).start(flute, settings);
                    open(const PracticeScreen());
                  },
                ),
              ),
            ),
    );
  }
}

class _FluteCard extends StatelessWidget {
  const _FluteCard({required this.flute, required this.onChange});
  final Flute flute;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = flute.calibratedAt == null
        ? null
        : DateTime.now().difference(flute.calibratedAt!).inDays;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(flute.name, style: theme.textTheme.titleLarge)),
                TextButton(onPressed: onChange, child: const Text('Change')),
              ],
            ),
            Text(
              flute.calibrated
                  ? 'Sa ${flute.saHz.toStringAsFixed(1)} Hz · calibrated '
                        '${age == 0
                            ? 'today'
                            : age == 1
                            ? 'yesterday'
                            : '$age days ago'}'
                  : 'Sa not calibrated yet: using the nominal ${flute.saHz.toStringAsFixed(1)} Hz',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: flute.calibrated ? null : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Sa shifts with breath and temperature, so a quick check before '
              'each session keeps the verdicts fair.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => showCalibrationSheet(context, flute),
              icon: const Icon(Icons.tune),
              label: Text(flute.calibrated ? 'Check Sa' : 'Calibrate Sa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Options extends ConsumerWidget {
  const _Options({required this.settings});
  final PracticeSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void save(PracticeSettings s) => ref.read(practiceSettingsProvider.notifier).save(s);
    final theme = Theme.of(context);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text, style: theme.textTheme.labelLarge),
    );

    Widget segments<T>(List<(T, String)> options, T selected, void Function(T) onSelect) =>
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [for (final o in options) ButtonSegment(value: o.$1, label: Text(o.$2))],
          selected: {selected},
          onSelectionChanged: (s) => onSelect(s.first),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('What the app plays'),
        segments(
          [for (final m in PracticeMode.values) (m, m.label)],
          settings.mode,
          (m) => save(settings.copyWith(mode: m)),
        ),
        label('Swars'),
        segments(
          [(SwarSet.saToPa, 'S–P'), (SwarSet.shuddha, 'Shuddha'), (SwarSet.all, '+ komal/tivra')],
          settings.swarSet,
          (v) => save(settings.copyWith(swarSet: v)),
        ),
        label('Octaves'),
        segments(
          [
            (SaptakRange.madhya, 'Madhya'),
            (SaptakRange.withMandra, '+ mandra'),
            (SaptakRange.all, 'All three'),
          ],
          settings.range,
          (v) => save(settings.copyWith(range: v)),
        ),
        label('Show the target'),
        segments(
          [
            (ShowTarget.always, 'Always'),
            (ShowTarget.roundEnd, 'Round end'),
            (ShowTarget.never, 'Never'),
          ],
          settings.showTarget,
          (v) => save(settings.copyWith(showTarget: v)),
        ),
        label('After a miss, show'),
        segments(
          [for (final r in MissReveal.values) (r, r.label)],
          settings.missReveal,
          (v) => save(settings.copyWith(missReveal: v)),
        ),
        label('After a miss'),
        segments(
          [(MissAction.wait, 'Wait for me'), (MissAction.autoRetry, 'Retry by itself')],
          settings.missAction,
          (v) => save(settings.copyWith(missAction: v)),
        ),
        if (settings.missAction == MissAction.autoRetry)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Replay the call before retrying'),
            value: settings.replayBeforeRetry,
            onChanged: (v) => save(settings.copyWith(replayBeforeRetry: v)),
          ),
        label('Give up and show the answer after'),
        segments(
          [(2, '2 misses'), (3, '3 misses'), (5, '5 misses'), (0, 'Never')],
          settings.giveUpAfter,
          (v) => save(settings.copyWith(giveUpAfter: v)),
        ),
        label('Tuning'),
        segments(
          [for (final t in TuningChoice.values) (t, t.label)],
          settings.tuning,
          (v) => save(settings.copyWith(tuning: v)),
        ),
        label('Tolerance'),
        segments(
          [(35.0, '±35 c'), (25.0, '±25 c'), (15.0, '±15 c')],
          settings.toleranceCents,
          (v) => save(settings.copyWith(toleranceCents: v)),
        ),
        label('Rounds'),
        segments(
          [(10, '10'), (20, '20'), (30, '30')],
          settings.rounds,
          (v) => save(settings.copyWith(rounds: v)),
        ),
        label('Script'),
        segments(
          [for (final s in Script.values) (s, s.label)],
          settings.script,
          (v) => save(settings.copyWith(script: v)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tanpura drone'),
          value: settings.droneOn,
          onChanged: (v) => save(settings.copyWith(droneOn: v)),
        ),
        if (settings.droneOn)
          Row(
            children: [
              const Text('Drone volume'),
              Expanded(
                child: Slider(
                  value: settings.droneVolume,
                  onChanged: (v) => save(settings.copyWith(droneVolume: v)),
                ),
              ),
            ],
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Strict intonation'),
          subtitle: const Text(
            'Off: the right swar passes and the cents are shown. On: it must also be within the tolerance',
          ),
          value: settings.strictIntonation,
          onChanged: (v) => save(settings.copyWith(strictIntonation: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Octave must match'),
          subtitle: const Text('Off: any octave of the right swar counts'),
          value: settings.octaveMustMatch,
          onChanged: (v) => save(settings.copyWith(octaveMustMatch: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Next round automatically after a pass'),
          value: settings.autoAdvance,
          onChanged: (v) => save(settings.copyWith(autoAdvance: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Save session audio'),
          subtitle: const Text(
            'Keeps each session\'s recording on the phone (about 11 MB a minute), '
            'so verdicts can be checked later',
          ),
          value: settings.saveSessionAudio,
          onChanged: (v) => save(settings.copyWith(saveSessionAudio: v)),
        ),
      ],
    );
  }
}
