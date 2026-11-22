import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../widgets/sargam.dart';
import 'practice_controller.dart';
import 'practice_settings.dart';
import 'session_summary.dart';

/// One practice session: the app plays, you play it back, it judges.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _revealed = false;
  int _shownRound = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: () => ref.read(practiceProvider.notifier).pause());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(practiceProvider);
    final controller = ref.read(practiceProvider.notifier);
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_shownRound != s.rounds.length) {
      _shownRound = s.rounds.length;
      _revealed = false;
    }

    if (s.phase == PracticePhase.finished) {
      return Scaffold(
        appBar: AppBar(title: Text('${s.flute.name} · done')),
        body: SessionSummaryView(rounds: _roundData(s), script: s.settings.script),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ),
      );
    }

    final round = s.round;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            round == null ? s.flute.name : 'Round ${round.number} of ${s.settings.rounds}',
          ),
          actions: [TextButton(onPressed: controller.finish, child: const Text('End'))],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                if (round != null) _target(context, s),
                const SizedBox(height: 32),
                _phase(context, s),
                const Spacer(),
                _buttons(context, s, controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The target, shown or hidden per the notation setting.
  Widget _target(BuildContext context, PracticeState s) {
    final round = s.round!;
    final result = s.lastResult;
    final judged = s.phase == PracticePhase.verdict && result != null;
    final show = switch (s.settings.notation) {
      NotationDisplay.shown => true,
      NotationDisplay.afterAttempt => judged || round.passed,
      NotationDisplay.hidden => round.passed || _revealed,
    };
    final scheme = Theme.of(context).colorScheme;
    if (!show) {
      return Column(
        children: [
          Wrap(
            spacing: 16,
            children: [
              for (final _ in round.target)
                Text('?', style: TextStyle(fontSize: 48, color: scheme.outline)),
            ],
          ),
          if (judged && s.settings.notation == NotationDisplay.hidden)
            TextButton(
              onPressed: () => setState(() => _revealed = true),
              child: const Text('Reveal'),
            ),
        ],
      );
    }
    final colors = judged
        ? [
            for (final n in result.targets)
              n.passed
                  ? scheme.primary
                  : n.verdict == Verdict.outOfTune
                  ? scheme.tertiary
                  : scheme.error,
          ]
        : null;
    return SargamRow(round.target, script: s.settings.script, size: 48, colors: colors);
  }

  Widget _phase(BuildContext context, PracticeState s) {
    final theme = Theme.of(context);
    switch (s.phase) {
      case PracticePhase.starting:
        return const CircularProgressIndicator();
      case PracticePhase.calling:
        return Column(
          children: [
            Icon(Icons.hearing, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text('Listen…', style: theme.textTheme.titleLarge),
          ],
        );
      case PracticePhase.listening:
        return Column(
          children: [
            Icon(Icons.mic, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text('Your turn', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(width: 200, child: LinearProgressIndicator(value: s.level)),
          ],
        );
      case PracticePhase.verdict:
        return _verdict(context, s);
      case PracticePhase.paused:
        return Text('Paused', style: theme.textTheme.titleLarge);
      case PracticePhase.error:
        return Text(
          s.message ?? 'Something went wrong',
          style: TextStyle(color: theme.colorScheme.error),
        );
      case PracticePhase.finished:
        return const SizedBox.shrink();
    }
  }

  Widget _verdict(BuildContext context, PracticeState s) {
    final theme = Theme.of(context);
    final result = s.lastResult!;
    final script = s.settings.script;
    final hidden = s.settings.notation == NotationDisplay.hidden && !s.round!.passed && !_revealed;
    return Column(
      children: [
        // A pass with some notes out of tune gets the in-between colour.
        Icon(
          result.passed ? Icons.check_circle : Icons.cancel,
          size: 56,
          color: !result.passed
              ? theme.colorScheme.error
              : result.inTune
              ? theme.colorScheme.primary
              : theme.colorScheme.tertiary,
        ),
        const SizedBox(height: 12),
        for (final n in result.notes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _describe(n, script, hideTarget: hidden),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
      ],
    );
  }

  static String _describe(JudgedNote n, Script script, {required bool hideTarget}) {
    String name(Pitch p) =>
        '${swarText(p.swar, script)}'
        '${p.swar.isKomal
            ? ' (komal)'
            : p.swar.isTivra
            ? ' (tivra)'
            : ''}'
        '${p.octave < 0
            ? ' mandra'
            : p.octave > 0
            ? ' taar'
            : ''}';
    String cents(double d) => '${d >= 0 ? '+' : '−'}${d.abs().round()} c';
    final target = n.target == null || hideTarget ? 'the note' : name(n.target!);
    return switch (n.verdict) {
      Verdict.pass => '✓ ${hideTarget ? 'Right' : target}  ${cents(n.deviation!)}',
      Verdict.outOfTune =>
        '✓ ${hideTarget ? 'Right swar' : target}, but ${n.deviation! < 0 ? 'flat' : 'sharp'} '
            '${cents(n.deviation!)}',
      Verdict.wrongSwar =>
        'You played ${name(n.played!.pitch)}${hideTarget ? '' : ', not $target'}',
      Verdict.wrongOctave => 'Right swar, wrong octave (${name(n.played!.pitch)})',
      Verdict.missing => hideTarget ? 'A note was missing' : '$target was missing',
      Verdict.extra => 'Extra note: ${name(n.played!.pitch)}',
    };
  }

  Widget _buttons(BuildContext context, PracticeState s, PracticeController controller) {
    final busy = s.phase == PracticePhase.starting || s.phase == PracticePhase.calling;
    final last = s.rounds.length >= s.settings.rounds;
    // Icon above label, so three buttons fit side by side on a phone.
    Widget content(IconData icon, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon), const SizedBox(height: 4), Text(label, maxLines: 1)],
    );
    const padding = EdgeInsets.symmetric(horizontal: 4, vertical: 12);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: padding),
            onPressed: busy ? null : controller.replay,
            child: content(Icons.replay, 'Replay'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: padding),
            onPressed: s.phase == PracticePhase.verdict || s.phase == PracticePhase.paused
                ? controller.retry
                : null,
            child: content(Icons.mic, 'Try again'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(padding: padding),
            onPressed: busy ? null : controller.next,
            child: content(last ? Icons.flag : Icons.arrow_forward, last ? 'Finish' : 'Next'),
          ),
        ),
      ],
    );
  }

  static List<RoundData> _roundData(PracticeState s) => [
    for (final r in s.rounds)
      RoundData(
        r.target,
        [
          for (final a in r.attempts)
            [for (final n in a.notes) NoteData(n.target, n.verdict, n.played?.pitch, n.deviation)],
        ],
        [for (final a in r.attempts) a.passed],
      ),
  ];
}
