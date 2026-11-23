import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/providers.dart';
import 'audio_service.dart';
import 'sound_delay.dart';

/// Shows the stored sound delay for the current output and measures it
/// again on request (docs/08 M3-C).
class SoundDelayTile extends ConsumerStatefulWidget {
  const SoundDelayTile({super.key});

  @override
  ConsumerState<SoundDelayTile> createState() => _SoundDelayTileState();
}

class _SoundDelayTileState extends ConsumerState<SoundDelayTile> {
  bool _measuring = false;
  String? _message;

  static String _when(DateTime at) {
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  Future<void> _measure(OutputRoute route) async {
    setState(() {
      _measuring = true;
      _message = null;
    });
    final audio = ref.read(audioServiceProvider);
    final db = ref.read(databaseProvider);
    final wasRunning = audio.running;
    String message;
    try {
      final settings = ref.read(practiceSettingsProvider).value;
      Directory? keepIn;
      if (settings?.saveSessionAudio ?? false) {
        final root =
            await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        keepIn = Directory('${root.path}/recordings/delay');
      }
      final m = await measureSoundDelay(audio, keepIn: keepIn);
      if (m != null && m.ok) {
        final delay = SoundDelay(
          route: route,
          ms: m.ms,
          spreadMs: m.spreadMs,
          measuredAt: DateTime.now(),
        );
        await db.setSetting(SoundDelay.key(route), jsonEncodeDelay(delay));
        message =
            '${m.ms.round()} ms. All ${m.heard} clicks agreed within '
            '${m.spreadMs.toStringAsFixed(1)} ms.';
        ref.invalidate(soundDelayProvider);
      } else {
        message =
            "The clicks weren't heard clearly (${m?.heard ?? 0} of $delayClicks). "
            "Turn the phone's volume up, keep the room quiet and try again.";
      }
    } on StateError catch (e) {
      message = e.message;
    } finally {
      if (!wasRunning) audio.stop();
    }
    if (mounted) {
      setState(() {
        _measuring = false;
        _message = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(soundDelayProvider);
    final theme = Theme.of(context);
    return current.when(
      loading: () => const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Sound delay'),
        subtitle: Text('Checking where the sound goes…'),
      ),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Sound delay'),
        subtitle: Text('$e'),
      ),
      data: (c) {
        final route = c.route;
        final delay = c.delay;
        final status = switch (route) {
          OutputRoute.bluetooth =>
            'Bluetooth is too slow and uneven to judge rhythm on. '
                'Use the phone speaker for rhythm practice.',
          OutputRoute.wired =>
            "With headphones the mic can't hear the clicks, so it can't be measured. "
                'For now, rhythm is measured on the phone speaker.',
          OutputRoute.speaker =>
            delay == null
                ? 'Phone speaker: not measured yet. Judging rhythm will need it.'
                : 'Phone speaker: ${delay.ms.round()} ms, measured ${_when(delay.measuredAt)}',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound delay'),
              subtitle: Text(
                _measuring
                    ? 'Listening for $delayClicks clicks… keep the phone still and the room quiet'
                    : status,
              ),
              trailing: _measuring
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : TextButton(
                      onPressed: route.measurable ? () => _measure(route) : null,
                      child: Text(delay == null ? 'Measure' : 'Measure again'),
                    ),
            ),
            if (_message != null && !_measuring) Text(_message!, style: theme.textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

/// [delay] as stored in the settings table.
String jsonEncodeDelay(SoundDelay delay) => jsonEncode(delay.toJson());
