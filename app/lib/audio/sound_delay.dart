import 'dart:convert';
import 'dart:io';

import 'package:aaroha_audio/aaroha_audio.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/providers.dart';
import 'audio_service.dart';

/// Where the phone's sound goes (docs/08 M3-C). The delay is measured and
/// stored for each.
enum OutputRoute {
  speaker('Phone speaker'),
  wired('Wired headphones'),
  bluetooth('Bluetooth');

  const OutputRoute(this.label);
  final String label;

  /// Only the speaker can be measured for now: with headphones the mic
  /// can't hear the clicks, and Bluetooth's delay is too long and uneven to
  /// judge rhythm on.
  bool get measurable => this == OutputRoute.speaker;
}

const _channel = MethodChannel('aaroha/audio_route');

/// The output sound goes to now; the speaker if the platform can't say.
Future<OutputRoute> currentOutputRoute() async {
  try {
    final name = await _channel.invokeMethod<String>('outputRoute');
    return OutputRoute.values.firstWhere((r) => r.name == name, orElse: () => OutputRoute.speaker);
  } on Object {
    return OutputRoute.speaker;
  }
}

/// A stored measurement of the sound's round trip for one output.
class SoundDelay {
  const SoundDelay({
    required this.route,
    required this.ms,
    required this.spreadMs,
    required this.measuredAt,
  });

  final OutputRoute route;
  final double ms;
  final double spreadMs;
  final DateTime measuredAt;

  static String key(OutputRoute route) => 'sound_delay_${route.name}';

  Map<String, Object?> toJson() => {
    'ms': double.parse(ms.toStringAsFixed(1)),
    'spreadMs': double.parse(spreadMs.toStringAsFixed(1)),
    'at': measuredAt.toIso8601String(),
  };

  static SoundDelay? fromJson(OutputRoute route, String? raw) {
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return SoundDelay(
        route: route,
        ms: (j['ms'] as num).toDouble(),
        spreadMs: (j['spreadMs'] as num).toDouble(),
        measuredAt: DateTime.parse(j['at'] as String),
      );
    } on Object {
      return null;
    }
  }
}

/// The current output and its stored delay, if measured.
final soundDelayProvider = FutureProvider.autoDispose<({OutputRoute route, SoundDelay? delay})>((
  ref,
) async {
  final route = await currentOutputRoute();
  final raw = await ref.watch(databaseProvider).setting(SoundDelay.key(route));
  return (route: route, delay: SoundDelay.fromJson(route, raw));
});

/// How many clicks a measurement plays, one a second (the delay must stay
/// under a second for each click to be found on its own).
const delayClicks = 6;

/// Measures how long the app's sound takes to reach its own mic: plays
/// [delayClicks] clicks with the drone silenced, records the mic, and finds
/// each click in the recording (docs/08 M3-C). With [keepIn], the recording
/// and what was played are kept there (as `delay-<time>.wav` and `.json`)
/// for checking on a computer; otherwise the recording is deleted. Throws
/// [StateError] when the mic can't be opened or is already recording.
Future<LatencyMeasurement?> measureSoundDelay(AudioService audio, {Directory? keepIn}) async {
  final fresh = !audio.capturing;
  if (!await audio.ensureStarted()) throw StateError('The microphone could not be opened.');
  // A device just opened can be a few milliseconds slow at first (seen on
  // the moto g45's first click); let it settle.
  if (fresh) await Future<void>.delayed(const Duration(milliseconds: 800));
  final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  final dir = keepIn ?? await getTemporaryDirectory();
  await dir.create(recursive: true);
  final wav = File('${dir.path}/delay-$stamp.wav');
  audio.quietDrone(true);
  try {
    try {
      audio.startRecording(wav.path);
    } on AudioEngineException {
      throw StateError('The microphone is busy recording.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sr = audio.sampleRate;
    final first = audio.time + (0.4 * sr).round();
    final clicks = [
      for (var k = 0; k < delayClicks; k++)
        ScheduledClick(time: first + k * sr, beat: Beat.sam, amplitude: 1),
    ];
    audio.playClicks(clicks);
    final end = clicks.last.time + (1.2 * sr).round();
    await Future<void>.delayed(Duration(microseconds: ((end - audio.time) * 1e6 / sr).round()));
    final start = audio.recordingStart;
    audio.stopRecording();
    if (start == null) return null;
    final decoded = decodeWav(await wav.readAsBytes());
    final played = [for (final c in clicks) c.time - start];
    final result = measureLatency(decoded.samples, decoded.sampleRate, played);
    if (keepIn != null) {
      await File('${dir.path}/delay-$stamp.json').writeAsString(
        jsonEncode({
          'sampleRate': decoded.sampleRate,
          'recordingStart': start,
          'clicks': played,
          'ms': result?.ms,
          'spreadMs': result?.spreadMs,
          'each': result?.each,
        }),
      );
    }
    return result;
  } finally {
    audio.quietDrone(false);
    if (keepIn == null && await wav.exists()) await wav.delete();
  }
}
