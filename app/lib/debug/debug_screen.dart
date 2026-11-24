import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_audio/aaroha_audio.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../audio/sound_delay_tile.dart';
import '../widgets/sargam.dart';
import 'debug_controller.dart';
import 'pitch_trace.dart';
import 'takes.dart';

/// M0 test build: live pitch readout, drone, Sa calibration and raw
/// recording for fixtures (docs/08-roadmap.md).
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _resumeOnShow = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        final controller = ref.read(debugControllerProvider.notifier);
        _resumeOnShow = ref.read(debugControllerProvider).status == EngineStatus.running;
        controller.stop();
      },
      onShow: () {
        if (_resumeOnShow) ref.read(debugControllerProvider.notifier).start();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(debugControllerProvider.notifier).start(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debugControllerProvider);
    final controller = ref.read(debugControllerProvider.notifier);
    final running = state.status == EngineStatus.running;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aaroha · test build'),
        actions: [
          IconButton(
            tooltip: running ? 'Stop engine' : 'Start engine',
            icon: Icon(running ? Icons.stop_circle_outlined : Icons.play_circle_outline),
            onPressed: running ? controller.stop : controller.start,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.status != EngineStatus.running) _StatusBanner(state: state),
            _FluteCard(state: state, controller: controller),
            const SizedBox(height: 12),
            _ReadingCard(state: state),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                  child: LivePitchTrace(trace: state.trace, length: traceFrames),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DroneCard(state: state, controller: controller),
            const SizedBox(height: 12),
            const Card(
              child: Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 12), child: SoundDelayTile()),
            ),
            const SizedBox(height: 12),
            _RecordCard(state: state, controller: controller),
            const SizedBox(height: 12),
            _EngineInfoCard(info: state.info),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});
  final DebugState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state.status) {
      EngineStatus.stopped => 'Engine stopped. Tap ▶ to start.',
      EngineStatus.starting => 'Starting audio…',
      EngineStatus.permissionDenied =>
        'Microphone permission is needed. Allow it in system settings, then tap ▶.',
      EngineStatus.error => 'Audio error: ${state.error}',
      EngineStatus.running => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
      ),
    );
  }
}

class _FluteCard extends StatelessWidget {
  const _FluteCard({required this.state, required this.controller});
  final DebugState state;
  final DebugController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<FluteKey>(
                    value: state.flute,
                    isExpanded: true,
                    items: [
                      for (final f in ownerFlutes) DropdownMenuItem(value: f, child: Text(f.name)),
                    ],
                    onChanged: (f) => f == null ? null : controller.selectFlute(f),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: state.calibrating || state.status != EngineStatus.running
                      ? null
                      : controller.calibrate,
                  child: Text(state.calibrating ? 'Listening…' : 'Calibrate Sa'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Sa ${state.saHz.toStringAsFixed(1)} Hz · '
              '${state.calibrated ? 'calibrated' : 'nominal'}',
              style: text.bodyMedium,
            ),
            if (state.message?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(state.message!, style: text.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.state});
  final DebugState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cents = state.cents;
    final nearest = cents == null ? null : Tuning.equal.nearest(cents);
    final deviation = nearest?.deviation;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              nearest?.pitch.ascii ?? '–',
              style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              nearest == null
                  ? 'play a note'
                  : '${nearest.pitch.swar.label} · ${nearest.pitch.saptakName}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _CentsMeter(deviation: deviation),
            const SizedBox(height: 4),
            Text(
              deviation == null
                  ? ' '
                  : '${deviation >= 0 ? '+' : '−'}${deviation.abs().toStringAsFixed(1)} cents',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${state.hz?.toStringAsFixed(2) ?? '–'} Hz · '
              '${cents?.toStringAsFixed(0) ?? '–'} c from Sa · '
              'conf ${state.confidence.toStringAsFixed(2)} · '
              '${state.rmsDb.toStringAsFixed(0)} dBFS',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CentsMeter extends StatelessWidget {
  const _CentsMeter({required this.deviation});
  final double? deviation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = deviation;
    final inTune = d != null && d.abs() <= 10;
    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final x = d == null ? null : w / 2 + (d.clamp(-50, 50) / 50) * (w / 2);
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                left: w / 2 - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: scheme.outline),
              ),
              if (x != null)
                Positioned(
                  left: x - 6,
                  top: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    decoration: BoxDecoration(
                      color: inTune ? scheme.primary : scheme.tertiary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DroneCard extends StatelessWidget {
  const _DroneCard({required this.state, required this.controller});
  final DebugState state;
  final DebugController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanpura drone'),
              subtitle: const Text('An octave below Sa'),
              value: state.droneOn,
              onChanged: (on) => controller.setDrone(on: on),
            ),
            Row(
              children: [
                const Text('Volume'),
                Expanded(
                  child: Slider(
                    value: state.droneVolume,
                    onChanged: (v) => controller.setDrone(volume: v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('First string'),
                const SizedBox(width: 12),
                SegmentedButton<DroneFirstString>(
                  segments: const [
                    ButtonSegment(value: DroneFirstString.pa, label: Text('Pa')),
                    ButtonSegment(value: DroneFirstString.ma, label: Text('Ma')),
                    ButtonSegment(value: DroneFirstString.ni, label: Text('Ni')),
                  ],
                  selected: {state.firstString},
                  onSelectionChanged: (s) => controller.setDrone(firstString: s.first),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Drone filter'),
              subtitle: const Text('Ignore pitches below the flute\'s range'),
              value: state.highpassOn,
              onChanged: controller.setHighpass,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({required this.state, required this.controller});
  final DebugState state;
  final DebugController controller;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  Timer? _clock;

  @override
  void didUpdateWidget(covariant _RecordCard old) {
    super.didUpdateWidget(old);
    final recording = widget.state.recordingSince != null;
    if (recording && _clock == null) {
      _clock = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
    } else if (!recording) {
      _clock?.cancel();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final since = state.recordingSince;
    final elapsed = since == null ? null : DateTime.now().difference(since);
    final running = state.status == EngineStatus.running;
    final text = Theme.of(context).textTheme;
    final needsDrone = state.take == Take.droneOnly || state.take == Take.withDrone;
    final warnings = [
      if (!state.calibrated) 'Sa not calibrated for this flute',
      if (needsDrone && !state.droneOn) 'This take needs the drone on',
      if (!needsDrone && state.droneOn && state.take != Take.other) 'Drone is on',
    ];
    final last = state.lastRecording;
    final shortPath = last == null || !last.contains('/recordings/')
        ? last
        : last.substring(last.indexOf('/recordings/') + 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<Take>(
              value: state.take,
              isExpanded: true,
              items: [
                for (final t in Take.values) DropdownMenuItem(value: t, child: Text('${t.id}.wav')),
              ],
              onChanged: since != null
                  ? null
                  : (t) => t == null ? null : widget.controller.selectTake(t),
            ),
            Text(state.take.instructions, style: text.bodyMedium),
            if (state.rhythmPhrase != null) ...[
              const SizedBox(height: 8),
              PhraseSargam(state.rhythmPhrase!, size: 24),
              const SizedBox(height: 8),
              Text(
                'Keherwa. Four clicks count you in; start on the next click (sam). '
                'Recording stops by itself.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 60, label: Text('60 a minute')),
                      ButtonSegment(value: 90, label: Text('90')),
                    ],
                    selected: {state.tempo},
                    onSelectionChanged: since != null
                        ? null
                        : (v) => widget.controller.setTempo(v.first),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Hear it'),
                    onPressed: running && since == null ? widget.controller.hearTake : null,
                  ),
                ],
              ),
            ],
            for (final w in warnings)
              Text(
                '⚠ $w',
                style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  icon: Icon(since == null ? Icons.fiber_manual_record : Icons.stop),
                  label: Text(
                    since != null
                        ? 'Stop'
                        : state.rhythmPhrase != null
                        ? 'Record with count-in'
                        : 'Record raw',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: since == null ? null : Theme.of(context).colorScheme.error,
                  ),
                  onPressed: !running
                      ? null
                      : since == null
                      ? widget.controller.startRecording
                      : widget.controller.stopRecording,
                ),
                const SizedBox(width: 12),
                if (elapsed != null)
                  Text(
                    '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              ],
            ),
            if (shortPath != null) ...[
              const SizedBox(height: 8),
              SelectableText(shortPath, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _EngineInfoCard extends StatelessWidget {
  const _EngineInfoCard({required this.info});
  final EngineInfo? info;

  @override
  Widget build(BuildContext context) {
    final i = info;
    final preset = switch (i?.inputPreset) {
      InputPreset.unprocessed => 'unprocessed',
      InputPreset.voiceRecognition => 'voice recognition',
      InputPreset.platformDefault => 'default (processed!)',
      InputPreset.none => 'none (playback only)',
      null => '–',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          i == null
              ? 'Engine: –'
              : 'Engine: ${i.backend} · ${i.sampleRate} Hz · mic preset $preset\n'
                    'Overruns: capture ${i.captureOverruns}, pitch ${i.pitchOverruns}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
