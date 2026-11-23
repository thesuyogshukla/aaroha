// Host-side bindings for the offline parts of the native core (ar_analyze,
// ar_render_drone, ar_render_notes, ar_render_clicks). The struct layouts mirror packages/aaroha_audio/src/aaroha_audio.h
// and are checked against the library at load time.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:aaroha_core/aaroha_core.dart';

final class _PitchFrame extends Struct {
  @Int64()
  external int time;
  @Float()
  external double hz;
  @Float()
  external double confidence;
  @Float()
  external double rms;
  @Float()
  external double reserved;
}

final class _TrackerConfig extends Struct {
  @Float()
  external double minHz;
  @Float()
  external double maxHz;
  @Float()
  external double threshold;
  @Float()
  external double highpassHz;
  @Int32()
  external int window;
  @Int32()
  external int hop;
}

final class _Note extends Struct {
  @Int64()
  external int start;
  @Int64()
  external int duration;
  @Double()
  external double hz;
  @Double()
  external double glideToHz;
  @Float()
  external double amplitude;
  @Float()
  external double reserved;
}

final class _Click extends Struct {
  @Int64()
  external int time;
  @Int32()
  external int beat;
  @Float()
  external double amplitude;
}

/// A flute-voice note for offline rendering, in samples from 0.
class VoiceNote {
  const VoiceNote(this.start, this.duration, this.hz, {this.glideToHz = 0, this.amplitude = 0.5});
  final int start;
  final int duration;
  final double hz;
  final double glideToHz;
  final double amplitude;
}

class NativeCore {
  NativeCore._(DynamicLibrary lib)
    : _abiVersion = lib.lookupFunction<Int32 Function(), int Function()>('ar_abi_version'),
      _sizeofPitchFrame = lib.lookupFunction<Int32 Function(), int Function()>(
        'ar_sizeof_pitch_frame',
      ),
      _sizeofTrackerConfig = lib.lookupFunction<Int32 Function(), int Function()>(
        'ar_sizeof_tracker_config',
      ),
      _defaultConfig = lib
          .lookupFunction<
            Void Function(Pointer<_TrackerConfig>),
            void Function(Pointer<_TrackerConfig>)
          >('ar_tracker_default_config'),
      _analyze = lib
          .lookupFunction<
            Int32 Function(
              Pointer<Float>,
              Int64,
              Int32,
              Pointer<_TrackerConfig>,
              Pointer<_PitchFrame>,
              Int32,
            ),
            int Function(
              Pointer<Float>,
              int,
              int,
              Pointer<_TrackerConfig>,
              Pointer<_PitchFrame>,
              int,
            )
          >('ar_analyze'),
      _renderDrone = lib
          .lookupFunction<
            Void Function(Double, Int32, Float, Int32, Pointer<Float>, Int64),
            void Function(double, int, double, int, Pointer<Float>, int)
          >('ar_render_drone'),
      _sizeofNote = lib.lookupFunction<Int32 Function(), int Function()>('ar_sizeof_note'),
      _renderNotes = lib
          .lookupFunction<
            Void Function(Pointer<_Note>, Int32, Int32, Pointer<Float>, Int64),
            void Function(Pointer<_Note>, int, int, Pointer<Float>, int)
          >('ar_render_notes'),
      _sizeofClick = lib.lookupFunction<Int32 Function(), int Function()>('ar_sizeof_click'),
      _renderClicks = lib
          .lookupFunction<
            Void Function(Pointer<_Click>, Int32, Int32, Pointer<Float>, Int64),
            void Function(Pointer<_Click>, int, int, Pointer<Float>, int)
          >('ar_render_clicks');

  /// Opens build/native-host/libaaroha_audio.dylib (see tools/build_native_host.sh).
  factory NativeCore.open([String? path]) {
    final libPath = path ?? '${repoRoot()}/build/native-host/libaaroha_audio.dylib';
    if (!File(libPath).existsSync()) {
      throw StateError('$libPath not found. Run tools/build_native_host.sh first.');
    }
    final core = NativeCore._(DynamicLibrary.open(libPath));
    if (core._abiVersion() != 5 ||
        core._sizeofClick() != sizeOf<_Click>() ||
        core._sizeofPitchFrame() != sizeOf<_PitchFrame>() ||
        core._sizeofTrackerConfig() != sizeOf<_TrackerConfig>() ||
        core._sizeofNote() != sizeOf<_Note>()) {
      throw StateError('native library does not match these bindings');
    }
    return core;
  }

  final int Function() _abiVersion;
  final int Function() _sizeofPitchFrame;
  final int Function() _sizeofTrackerConfig;
  final void Function(Pointer<_TrackerConfig>) _defaultConfig;
  final int Function(Pointer<Float>, int, int, Pointer<_TrackerConfig>, Pointer<_PitchFrame>, int)
  _analyze;
  final void Function(double, int, double, int, Pointer<Float>, int) _renderDrone;
  final int Function() _sizeofNote;
  final void Function(Pointer<_Note>, int, int, Pointer<Float>, int) _renderNotes;
  final int Function() _sizeofClick;
  final void Function(Pointer<_Click>, int, int, Pointer<Float>, int) _renderClicks;

  /// The engine's metronome clicks: (sample, beat) pairs, beat as [Beat].
  Float32List renderClicks(
    List<(int, Beat)> clicks,
    int sampleRate,
    int length, {
    double amplitude = 1,
  }) {
    final input = calloc<_Click>(clicks.length);
    final out = calloc<Float>(length);
    try {
      for (var i = 0; i < clicks.length; i++) {
        (input + i).ref
          ..time = clicks[i].$1
          ..beat = clicks[i].$2.index
          ..amplitude = amplitude;
      }
      _renderClicks(input, clicks.length, sampleRate, out, length);
      return Float32List.fromList(out.asTypedList(length));
    } finally {
      calloc
        ..free(input)
        ..free(out);
    }
  }

  /// The engine's flute voice playing [notes].
  Float32List renderNotes(List<VoiceNote> notes, int sampleRate, int length) {
    final input = calloc<_Note>(notes.length);
    final out = calloc<Float>(length);
    try {
      for (var i = 0; i < notes.length; i++) {
        (input + i).ref
          ..start = notes[i].start
          ..duration = notes[i].duration
          ..hz = notes[i].hz
          ..glideToHz = notes[i].glideToHz
          ..amplitude = notes[i].amplitude;
      }
      _renderNotes(input, notes.length, sampleRate, out, length);
      return Float32List.fromList(out.asTypedList(length));
    } finally {
      calloc
        ..free(input)
        ..free(out);
    }
  }

  /// Runs the tracker over [samples]. [highpassHz] 0 disables the filter;
  /// [minHz] overrides the lowest pitch searched.
  List<PitchFrame> analyze(
    Float32List samples,
    int sampleRate, {
    double highpassHz = 0,
    double? minHz,
  }) {
    final input = calloc<Float>(samples.length);
    final config = calloc<_TrackerConfig>();
    _defaultConfig(config);
    config.ref.highpassHz = highpassHz;
    if (minHz != null) config.ref.minHz = minHz;
    final max = samples.length ~/ config.ref.hop + 1;
    final output = calloc<_PitchFrame>(max);
    try {
      input.asTypedList(samples.length).setAll(0, samples);
      final count = _analyze(input, samples.length, sampleRate, config, output, max);
      return [
        for (var i = 0; i < count; i++)
          PitchFrame(
            time: (output + i).ref.time,
            hz: (output + i).ref.hz,
            confidence: (output + i).ref.confidence,
            rms: (output + i).ref.rms,
          ),
      ];
    } finally {
      calloc
        ..free(input)
        ..free(config)
        ..free(output);
    }
  }

  /// The engine's drone for [saHz], with Pa as the first string.
  Float32List renderDrone(double saHz, int sampleRate, int length, {double volume = 0.5}) {
    final out = calloc<Float>(length);
    try {
      _renderDrone(saHz, 0, volume, sampleRate, out, length);
      return Float32List.fromList(out.asTypedList(length));
    } finally {
      calloc.free(out);
    }
  }
}

/// The repository root, found from this script's location.
String repoRoot() {
  var dir = File.fromUri(Platform.script).parent;
  while (!File('${dir.path}/CLAUDE.md').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current.path;
    dir = parent;
  }
  return dir.path;
}
