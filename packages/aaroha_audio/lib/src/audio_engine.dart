import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:aaroha_core/aaroha_core.dart';

import 'call.dart';
import 'native.dart';

/// `none`: a playback-only engine (see [AudioEngine.setCapture]).
enum InputPreset { unprocessed, voiceRecognition, platformDefault, none }

/// The tanpura's first string (docs/02-music-model.md).
enum DroneFirstString { pa, ma, ni }

class TrackerConfig {
  const TrackerConfig({
    this.minHz = 150,
    this.maxHz = 2500,
    this.threshold = 0.15,
    this.highpassHz = 0,
    this.window = 1024,
    this.hop = 480,
  });

  final double minHz;
  final double maxHz;
  final double threshold;

  /// 0 disables the high-pass. Set to ~0.7× the flute's lowest note to keep
  /// the drone out of the analysis.
  final double highpassHz;
  final int window;
  final int hop;

  TrackerConfig copyWith({double? highpassHz}) => TrackerConfig(
    minHz: minHz,
    maxHz: maxHz,
    threshold: threshold,
    highpassHz: highpassHz ?? this.highpassHz,
    window: window,
    hop: hop,
  );
}

class EngineInfo {
  const EngineInfo({
    required this.sampleRate,
    required this.inputPreset,
    required this.running,
    required this.recording,
    required this.captureOverruns,
    required this.pitchOverruns,
    required this.backend,
  });

  final int sampleRate;
  final InputPreset inputPreset;
  final bool running;
  final bool recording;
  final int captureOverruns;
  final int pitchOverruns;
  final String backend;
}

class AudioEngineException implements Exception {
  AudioEngineException(this.message, [this.code]);
  final String message;
  final int? code;

  @override
  String toString() => 'AudioEngineException: $message${code == null ? '' : ' ($code)'}';
}

/// Dart side of the native engine. Call from one isolate only.
class AudioEngine {
  AudioEngine._(this._native, this._engine)
    : _frameBuffer = calloc<ArPitchFrame>(_bufferFrames),
      _info = calloc<ArEngineInfo>(),
      _config = calloc<ArTrackerConfig>(),
      _notes = calloc<ArNote>(arMaxSequenceNotes),
      _clicks = calloc<ArClick>(arMaxClicks);

  factory AudioEngine.create({int sampleRate = 48000, DynamicLibrary? library}) {
    final native = NativeBindings(library ?? openNativeLibrary())..checkAbi();
    final engine = native.engineCreate(sampleRate);
    if (engine == nullptr) throw AudioEngineException('could not create engine');
    return AudioEngine._(native, engine);
  }

  static const _bufferFrames = 512;

  final NativeBindings _native;
  final Pointer<ArEngine> _engine;
  final Pointer<ArPitchFrame> _frameBuffer;
  final Pointer<ArEngineInfo> _info;
  final Pointer<ArTrackerConfig> _config;
  final Pointer<ArNote> _notes;
  final Pointer<ArClick> _clicks;
  bool _disposed = false;

  void start() {
    final result = _native.engineStart(_engine);
    if (result != 0) throw AudioEngineException('could not start audio device', result);
  }

  void stop() => _native.engineStop(_engine);

  /// Whether the next [start] opens the mic. Off gives a playback-only
  /// engine: drone and flute voice, no capture, no mic permission needed.
  void setCapture(bool on) => _native.setCapture(_engine, on ? 1 : 0);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _native.engineDestroy(_engine);
    calloc
      ..free(_frameBuffer)
      ..free(_info)
      ..free(_config)
      ..free(_notes)
      ..free(_clicks);
  }

  /// Engine frames processed since start.
  int get time => _native.engineTime(_engine);

  EngineInfo get info {
    _native.engineGetInfo(_engine, _info);
    final i = _info.ref;
    final bytes = <int>[];
    for (var k = 0; k < 32 && i.backend[k] != 0; k++) {
      bytes.add(i.backend[k]);
    }
    return EngineInfo(
      sampleRate: i.sampleRate,
      inputPreset: InputPreset.values[i.inputPreset.clamp(0, 3)],
      running: i.running != 0,
      recording: i.recording != 0,
      captureOverruns: i.captureOverruns,
      pitchOverruns: i.pitchOverruns,
      backend: String.fromCharCodes(bytes),
    );
  }

  /// [saHz] is the flute's Sa; the drone plays an octave below it.
  void setDrone({
    required double saHz,
    DroneFirstString firstString = DroneFirstString.pa,
    double volume = 0.5,
    required bool on,
  }) => _native.droneSet(_engine, saHz, firstString.index, volume, on ? 1 : 0);

  void setTracker(TrackerConfig config) {
    _config.ref
      ..minHz = config.minHz
      ..maxHz = config.maxHz
      ..threshold = config.threshold
      ..highpassHz = config.highpassHz
      ..window = config.window
      ..hop = config.hop;
    _native.trackerSet(_engine, _config);
  }

  /// Turn-taking gate: while false, captured audio is discarded.
  set captureEnabled(bool on) => _native.captureEnable(_engine, on ? 1 : 0);

  /// Everything the tracker has produced since the last call.
  List<PitchFrame> readFrames() {
    final frames = <PitchFrame>[];
    while (true) {
      final count = _native.readPitchFrames(_engine, _frameBuffer, _bufferFrames);
      for (var k = 0; k < count; k++) {
        final f = (_frameBuffer + k).ref;
        frames.add(PitchFrame(time: f.time, hz: f.hz, confidence: f.confidence, rms: f.rms));
      }
      if (count < _bufferFrames) return frames;
    }
  }

  /// Schedules the flute voice (replacing anything scheduled). Times are
  /// engine frames; see [scheduleCall].
  void play(List<ScheduledNote> notes) {
    if (notes.length > arMaxSequenceNotes) {
      throw AudioEngineException('at most $arMaxSequenceNotes notes per call');
    }
    for (var i = 0; i < notes.length; i++) {
      (_notes + i).ref
        ..start = notes[i].start
        ..duration = notes[i].duration
        ..hz = notes[i].hz
        ..glideToHz = notes[i].glideToHz ?? 0
        ..amplitude = notes[i].amplitude;
    }
    if (_native.playSequence(_engine, _notes, notes.length) != 0) {
      throw AudioEngineException('playback queue is full');
    }
  }

  void stopPlayback() => _native.stopPlayback(_engine);

  /// Schedules metronome clicks (replacing any scheduled); see
  /// [scheduleClicks].
  void playClicks(List<ScheduledClick> clicks) {
    if (clicks.length > arMaxClicks) {
      throw AudioEngineException('at most $arMaxClicks clicks at once');
    }
    for (var i = 0; i < clicks.length; i++) {
      (_clicks + i).ref
        ..time = clicks[i].time
        ..beat = clicks[i].beat.index
        ..amplitude = clicks[i].amplitude;
    }
    if (_native.playClicks(_engine, _clicks, clicks.length) != 0) {
      throw AudioEngineException('click queue is full');
    }
  }

  void stopClicks() => _native.stopClicks(_engine);

  /// Records the raw mic stream as 32-bit float mono WAV.
  void startRecording(String path) {
    final cPath = path.toNativeUtf8();
    try {
      if (_native.recordStart(_engine, cPath.cast()) != 0) {
        throw AudioEngineException('could not start recording to $path');
      }
    } finally {
      calloc.free(cPath);
    }
  }

  /// Returns the number of frames written.
  int stopRecording() => _native.recordStop(_engine);

  /// The engine frame of the recording's first sample, or null before any
  /// audio was written.
  int? get recordingStart {
    final f = _native.recordFirstFrame(_engine);
    return f < 0 ? null : f;
  }
}
