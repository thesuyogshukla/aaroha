// Raw dart:ffi bindings for src/aaroha_audio.h. Keep in sync with the header;
// struct sizes are checked against the library at load time.

import 'dart:ffi';
import 'dart:io';

const arAbiVersion = 5;
const arMaxSequenceNotes = 128;
const arMaxClicks = 256;

final class ArPitchFrame extends Struct {
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

final class ArTrackerConfig extends Struct {
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

final class ArEngineInfo extends Struct {
  @Int32()
  external int sampleRate;
  @Int32()
  external int inputPreset;
  @Int32()
  external int running;
  @Int32()
  external int recording;
  @Int64()
  external int captureOverruns;
  @Int64()
  external int pitchOverruns;
  @Array(32)
  external Array<Uint8> backend;
}

final class ArNote extends Struct {
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

final class ArClick extends Struct {
  @Int64()
  external int time;
  @Int32()
  external int beat;
  @Float()
  external double amplitude;
}

final class ArEngine extends Opaque {}

class NativeBindings {
  NativeBindings(DynamicLibrary lib)
    : abiVersion = lib.lookupFunction<Int32 Function(), int Function()>('ar_abi_version'),
      sizeofPitchFrame = lib.lookupFunction<Int32 Function(), int Function()>(
        'ar_sizeof_pitch_frame',
      ),
      sizeofTrackerConfig = lib.lookupFunction<Int32 Function(), int Function()>(
        'ar_sizeof_tracker_config',
      ),
      sizeofEngineInfo = lib.lookupFunction<Int32 Function(), int Function()>(
        'ar_sizeof_engine_info',
      ),
      trackerDefaultConfig = lib
          .lookupFunction<
            Void Function(Pointer<ArTrackerConfig>),
            void Function(Pointer<ArTrackerConfig>)
          >('ar_tracker_default_config'),
      engineCreate = lib
          .lookupFunction<Pointer<ArEngine> Function(Int32), Pointer<ArEngine> Function(int)>(
            'ar_engine_create',
          ),
      engineStart = lib
          .lookupFunction<Int32 Function(Pointer<ArEngine>), int Function(Pointer<ArEngine>)>(
            'ar_engine_start',
          ),
      engineStop = lib
          .lookupFunction<Void Function(Pointer<ArEngine>), void Function(Pointer<ArEngine>)>(
            'ar_engine_stop',
          ),
      engineDestroy = lib
          .lookupFunction<Void Function(Pointer<ArEngine>), void Function(Pointer<ArEngine>)>(
            'ar_engine_destroy',
          ),
      engineTime = lib
          .lookupFunction<Int64 Function(Pointer<ArEngine>), int Function(Pointer<ArEngine>)>(
            'ar_engine_time',
          ),
      engineGetInfo = lib
          .lookupFunction<
            Void Function(Pointer<ArEngine>, Pointer<ArEngineInfo>),
            void Function(Pointer<ArEngine>, Pointer<ArEngineInfo>)
          >('ar_engine_get_info'),
      droneSet = lib
          .lookupFunction<
            Void Function(Pointer<ArEngine>, Double, Int32, Float, Int32),
            void Function(Pointer<ArEngine>, double, int, double, int)
          >('ar_drone_set'),
      trackerSet = lib
          .lookupFunction<
            Void Function(Pointer<ArEngine>, Pointer<ArTrackerConfig>),
            void Function(Pointer<ArEngine>, Pointer<ArTrackerConfig>)
          >('ar_tracker_set'),
      captureEnable = lib
          .lookupFunction<
            Void Function(Pointer<ArEngine>, Int32),
            void Function(Pointer<ArEngine>, int)
          >('ar_capture_enable'),
      readPitchFrames = lib
          .lookupFunction<
            Int32 Function(Pointer<ArEngine>, Pointer<ArPitchFrame>, Int32),
            int Function(Pointer<ArEngine>, Pointer<ArPitchFrame>, int)
          >('ar_read_pitch_frames'),
      recordStart = lib
          .lookupFunction<
            Int32 Function(Pointer<ArEngine>, Pointer<Char>),
            int Function(Pointer<ArEngine>, Pointer<Char>)
          >('ar_record_start'),
      recordStop = lib
          .lookupFunction<Int64 Function(Pointer<ArEngine>), int Function(Pointer<ArEngine>)>(
            'ar_record_stop',
          ),
      recordFirstFrame = lib
          .lookupFunction<Int64 Function(Pointer<ArEngine>), int Function(Pointer<ArEngine>)>(
            'ar_record_first_frame',
          ),
      sizeofNote = lib.lookupFunction<Int32 Function(), int Function()>('ar_sizeof_note'),
      playSequence = lib
          .lookupFunction<
            Int32 Function(Pointer<ArEngine>, Pointer<ArNote>, Int32),
            int Function(Pointer<ArEngine>, Pointer<ArNote>, int)
          >('ar_play_sequence'),
      stopPlayback = lib
          .lookupFunction<Void Function(Pointer<ArEngine>), void Function(Pointer<ArEngine>)>(
            'ar_stop_playback',
          ),
      sizeofClick = lib.lookupFunction<Int32 Function(), int Function()>('ar_sizeof_click'),
      playClicks = lib
          .lookupFunction<
            Int32 Function(Pointer<ArEngine>, Pointer<ArClick>, Int32),
            int Function(Pointer<ArEngine>, Pointer<ArClick>, int)
          >('ar_play_clicks'),
      stopClicks = lib
          .lookupFunction<Void Function(Pointer<ArEngine>), void Function(Pointer<ArEngine>)>(
            'ar_stop_clicks',
          ),
      setCapture = lib
          .lookupFunction<
            Void Function(Pointer<ArEngine>, Int32),
            void Function(Pointer<ArEngine>, int)
          >('ar_engine_set_capture');

  final int Function() abiVersion;
  final int Function() sizeofPitchFrame;
  final int Function() sizeofTrackerConfig;
  final int Function() sizeofEngineInfo;
  final void Function(Pointer<ArTrackerConfig>) trackerDefaultConfig;
  final Pointer<ArEngine> Function(int) engineCreate;
  final int Function(Pointer<ArEngine>) engineStart;
  final void Function(Pointer<ArEngine>) engineStop;
  final void Function(Pointer<ArEngine>) engineDestroy;
  final int Function(Pointer<ArEngine>) engineTime;
  final void Function(Pointer<ArEngine>, Pointer<ArEngineInfo>) engineGetInfo;
  final void Function(Pointer<ArEngine>, double, int, double, int) droneSet;
  final void Function(Pointer<ArEngine>, Pointer<ArTrackerConfig>) trackerSet;
  final void Function(Pointer<ArEngine>, int) captureEnable;
  final int Function(Pointer<ArEngine>, Pointer<ArPitchFrame>, int) readPitchFrames;
  final int Function(Pointer<ArEngine>, Pointer<Char>) recordStart;
  final int Function(Pointer<ArEngine>) recordStop;
  final int Function(Pointer<ArEngine>) recordFirstFrame;
  final int Function() sizeofNote;
  final int Function(Pointer<ArEngine>, Pointer<ArNote>, int) playSequence;
  final void Function(Pointer<ArEngine>) stopPlayback;
  final int Function() sizeofClick;
  final int Function(Pointer<ArEngine>, Pointer<ArClick>, int) playClicks;
  final void Function(Pointer<ArEngine>) stopClicks;
  final void Function(Pointer<ArEngine>, int) setCapture;

  /// Throws if the loaded library doesn't match these bindings.
  void checkAbi() {
    final problems = <String>[
      if (abiVersion() != arAbiVersion) 'ABI version ${abiVersion()} != $arAbiVersion',
      if (sizeofNote() != sizeOf<ArNote>()) 'ar_note ${sizeofNote()} != ${sizeOf<ArNote>()} bytes',
      if (sizeofClick() != sizeOf<ArClick>())
        'ar_click ${sizeofClick()} != ${sizeOf<ArClick>()} bytes',
      if (sizeofPitchFrame() != sizeOf<ArPitchFrame>())
        'ar_pitch_frame ${sizeofPitchFrame()} != ${sizeOf<ArPitchFrame>()} bytes',
      if (sizeofTrackerConfig() != sizeOf<ArTrackerConfig>())
        'ar_tracker_config ${sizeofTrackerConfig()} != ${sizeOf<ArTrackerConfig>()} bytes',
      if (sizeofEngineInfo() != sizeOf<ArEngineInfo>())
        'ar_engine_info ${sizeofEngineInfo()} != ${sizeOf<ArEngineInfo>()} bytes',
    ];
    if (problems.isNotEmpty) {
      throw StateError('aaroha_audio native library mismatch: ${problems.join('; ')}');
    }
  }
}

DynamicLibrary openNativeLibrary() {
  if (Platform.isAndroid || Platform.isLinux) return DynamicLibrary.open('libaaroha_audio.so');
  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.open('aaroha_audio.framework/aaroha_audio');
  }
  throw UnsupportedError('aaroha_audio: unsupported platform ${Platform.operatingSystem}');
}
