import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_audio/aaroha_audio.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:permission_handler/permission_handler.dart';

enum AudioStatus { stopped, starting, running, permissionDenied, error }

/// The single native engine for the whole app (the phone can run only one
/// full-duplex stream). Screens subscribe to [frames]; the engine polls
/// pitch frames ~60 times a second while it runs.
class AudioService {
  AudioService();

  AudioEngine? _engine;
  Timer? _poll;
  final _frames = StreamController<List<PitchFrame>>.broadcast();
  final _status = StreamController<AudioStatus>.broadcast();
  AudioStatus _current = AudioStatus.stopped;
  String? lastError;

  // Remembered so they can be re-applied after a restart.
  TrackerConfig _tracker = const TrackerConfig();
  ({double saHz, DroneFirstString firstString, double volume, bool on})? _drone;

  // Round-trip delay from scheduling a sound to its tracker frames: output
  // latency + room + input latency (decisions.md D28). Measured from every
  // call the app plays; until then, a safe default.
  static const defaultLoopbackMs = 450.0;
  final _loopbackSamples = <double>[];
  double _loopbackMs = defaultLoopbackMs;

  /// Median of recent measurements, in milliseconds.
  double get loopbackMs => _loopbackMs;
  int get loopbackFrames => (_loopbackMs * sampleRate / 1000).round();
  bool get loopbackMeasured => _loopbackSamples.isNotEmpty;

  /// Starts from a value saved on an earlier run.
  void restoreLoopback(double ms) {
    if (_loopbackSamples.isEmpty) _loopbackMs = ms.clamp(20, 1000).toDouble();
  }

  void reportLoopback(double ms) {
    if (ms < 20 || ms > 1000) return; // not the call coming back
    _loopbackSamples.add(ms);
    if (_loopbackSamples.length > 9) _loopbackSamples.removeAt(0);
    final sorted = [..._loopbackSamples]..sort();
    _loopbackMs = sorted[sorted.length ~/ 2];
  }

  /// Pitch frames, in batches, as the tracker produces them.
  Stream<List<PitchFrame>> get frames => _frames.stream;
  Stream<AudioStatus> get statusChanges => _status.stream;
  AudioStatus get status => _current;
  bool get running => _current == AudioStatus.running;

  /// Engine frames since start; 0 when stopped.
  int get time => _engine?.time ?? 0;
  int get sampleRate => _engine?.info.sampleRate ?? 48000;
  EngineInfo? get info => _engine?.info;

  bool _capturing = true;

  /// Whether the running engine has the mic open.
  bool get capturing => running && _capturing;

  /// Starts the engine. With [capture] false it runs playback only: the
  /// drone and flute voice, no mic and no mic permission (Listen & name).
  /// A running engine in the other mode is restarted.
  Future<bool> ensureStarted({bool capture = true}) async {
    if (running && _capturing == capture) return true;
    if (running) stop();
    _setStatus(AudioStatus.starting);
    if (capture && !(await Permission.microphone.request()).isGranted) {
      _setStatus(AudioStatus.permissionDenied);
      return false;
    }
    try {
      final engine = _engine ??= AudioEngine.create();
      engine.setCapture(capture);
      _capturing = capture;
      engine.setTracker(_tracker);
      final d = _drone;
      if (d != null) {
        engine.setDrone(saHz: d.saHz, firstString: d.firstString, volume: d.volume, on: d.on);
      }
      engine.start();
      _poll = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final batch = engine.readFrames();
        if (batch.isNotEmpty) _frames.add(batch);
      });
      _setStatus(AudioStatus.running);
      return true;
    } on Object catch (e) {
      lastError = '$e';
      _setStatus(AudioStatus.error);
      return false;
    }
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    _engine?.stop();
    _setStatus(AudioStatus.stopped);
  }

  /// Tracker settings for a flute: the drone filter limits the search to the
  /// flute's range (decisions.md D17).
  void configureFor(double saHz, {bool droneFilter = true}) {
    final lowest = hzFromCents(-500, saHz);
    _tracker = droneFilter
        ? TrackerConfig(highpassHz: 0.7 * lowest, minHz: hzFromCents(-700, saHz))
        : const TrackerConfig();
    _engine?.setTracker(_tracker);
  }

  void setDrone({
    required double saHz,
    DroneFirstString firstString = DroneFirstString.pa,
    double volume = 0.5,
    required bool on,
  }) {
    _drone = (saHz: saHz, firstString: firstString, volume: volume, on: on);
    _engine?.setDrone(saHz: saHz, firstString: firstString, volume: volume, on: on);
  }

  void play(List<ScheduledNote> notes) => _engine?.play(notes);
  void stopPlayback() => _engine?.stopPlayback();

  void startRecording(String path) => _engine?.startRecording(path);
  int stopRecording() => _engine?.stopRecording() ?? 0;

  void dispose() {
    stop();
    _engine?.dispose();
    _engine = null;
    _frames.close();
    _status.close();
  }

  void _setStatus(AudioStatus s) {
    _current = s;
    _status.add(s);
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
