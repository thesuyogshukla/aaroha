import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_audio/aaroha_audio.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:path_provider/path_provider.dart';
import '../audio/audio_service.dart';
import '../audio/sa_calibrator.dart';

import '../data/providers.dart';
import 'takes.dart';

enum EngineStatus { stopped, starting, running, permissionDenied, error }

/// How many frames the live trace keeps (100 frames per second).
const traceFrames = 500;

class DebugState {
  const DebugState({
    this.status = EngineStatus.stopped,
    this.error,
    this.flute = const FluteKey(PitchClass.g, FluteSize.medium),
    this.saHz = 392.0,
    this.calibrated = false,
    this.calibrating = false,
    this.message,
    this.droneOn = false,
    this.droneVolume = 0.5,
    this.firstString = DroneFirstString.pa,
    this.highpassOn = true,
    this.hz,
    this.confidence = 0,
    this.rmsDb = -120,
    this.trace = const [],
    this.info,
    this.recordingSince,
    this.lastRecording,
    this.take = Take.saHold,
    this.tempo = 60,
  });

  final EngineStatus status;
  final String? error;
  final FluteKey flute;
  final double saHz;
  final bool calibrated;
  final bool calibrating;

  /// Last calibration or recording outcome, shown to the player.
  final String? message;
  final bool droneOn;
  final double droneVolume;
  final DroneFirstString firstString;
  final bool highpassOn;

  /// Smoothed current pitch, null while nothing is being played.
  final double? hz;
  final double confidence;
  final double rmsDb;

  /// Cents from Sa for the last [traceFrames] frames; null = unvoiced.
  final List<double?> trace;
  final EngineInfo? info;
  final DateTime? recordingSince;
  final String? lastRecording;

  /// Which fixture take the next recording is.
  final Take take;

  /// Matras a minute for a rhythm take (docs/08 M3-D).
  final int tempo;

  /// The rhythm take's phrase, in keherwa.
  Phrase? get rhythmPhrase =>
      take.rhythm == null ? null : parsePhrase('taal: keherwa\n---\n${take.rhythm}');

  double? get cents => hz == null ? null : centsFromSa(hz!, saHz);

  DebugState copyWith({
    EngineStatus? status,
    String? error,
    FluteKey? flute,
    double? saHz,
    bool? calibrated,
    bool? calibrating,
    String? message,
    bool? droneOn,
    double? droneVolume,
    DroneFirstString? firstString,
    bool? highpassOn,
    double? Function()? hz,
    double? confidence,
    double? rmsDb,
    List<double?>? trace,
    EngineInfo? info,
    DateTime? Function()? recordingSince,
    String? lastRecording,
    Take? take,
    int? tempo,
  }) => DebugState(
    status: status ?? this.status,
    error: error ?? this.error,
    flute: flute ?? this.flute,
    saHz: saHz ?? this.saHz,
    calibrated: calibrated ?? this.calibrated,
    calibrating: calibrating ?? this.calibrating,
    message: message ?? this.message,
    droneOn: droneOn ?? this.droneOn,
    droneVolume: droneVolume ?? this.droneVolume,
    firstString: firstString ?? this.firstString,
    highpassOn: highpassOn ?? this.highpassOn,
    hz: hz != null ? hz() : this.hz,
    confidence: confidence ?? this.confidence,
    rmsDb: rmsDb ?? this.rmsDb,
    trace: trace ?? this.trace,
    info: info ?? this.info,
    recordingSince: recordingSince != null ? recordingSince() : this.recordingSince,
    lastRecording: lastRecording ?? this.lastRecording,
    take: take ?? this.take,
    tempo: tempo ?? this.tempo,
  );
}

final debugControllerProvider = NotifierProvider<DebugController, DebugState>(DebugController.new);

/// The M0 debug screen, on the shared audio engine: live pitch readout,
/// drone, Sa calibration and raw fixture recording.
class DebugController extends Notifier<DebugState> {
  StreamSubscription<List<PitchFrame>>? _frames;
  DebugState? _recordingSnapshot;
  int _ticks = 0;
  final _trace = <double?>[];
  final _recentHz = <double>[];
  int _unvoicedRun = 0;
  SaCalibrator? _calibrator;

  static const _minConfidence = 0.85;

  AudioService get _audio => ref.read(audioServiceProvider);

  @override
  DebugState build() {
    ref.onDispose(() => _frames?.cancel());
    final flute = ownerFlutes.first;
    return DebugState(flute: flute, saHz: flute.nominalSaHz);
  }

  Future<void> start() async {
    if (state.status == EngineStatus.running || state.status == EngineStatus.starting) return;
    state = state.copyWith(status: EngineStatus.starting);
    _applyTracker();
    _applyDrone();
    final ok = await _audio.ensureStarted();
    state = state.copyWith(
      status: switch (_audio.status) {
        AudioStatus.running => EngineStatus.running,
        AudioStatus.permissionDenied => EngineStatus.permissionDenied,
        AudioStatus.error => EngineStatus.error,
        _ => EngineStatus.stopped,
      },
      error: _audio.lastError,
      info: _audio.info,
    );
    if (ok) {
      await _frames?.cancel();
      _frames = _audio.frames.listen(_onFrames);
    }
  }

  void stop() {
    _frames?.cancel();
    _frames = null;
    if (state.recordingSince != null) stopRecording();
    _audio.stop();
    state = state.copyWith(status: EngineStatus.stopped, hz: () => null);
  }

  void selectFlute(FluteKey flute) {
    state = state.copyWith(flute: flute, saHz: flute.nominalSaHz, calibrated: false, message: '');
    _applyTracker();
    _applyDrone();
  }

  void setDrone({bool? on, double? volume, DroneFirstString? firstString}) {
    state = state.copyWith(droneOn: on, droneVolume: volume, firstString: firstString);
    _applyDrone();
  }

  void setHighpass(bool on) {
    state = state.copyWith(highpassOn: on);
    _applyTracker();
  }

  /// Collects 3 seconds of the player holding Sa and adopts its median.
  void calibrate() {
    _calibrator = SaCalibrator(state.flute);
    state = state.copyWith(
      calibrating: true,
      message: 'Play Sa with a relaxed breath and hold it…',
    );
  }

  void selectTake(Take take) => state = state.copyWith(take: take);

  void setTempo(int tempo) => state = state.copyWith(tempo: tempo);

  /// Where a rhythm take's clicks and sam fell, in engine frames.
  ({List<ScheduledClick> clicks, int sam, double? soundDelayMs})? _rhythm;
  Timer? _autoStop;

  static int _matras(Phrase p) {
    final l = p.length;
    return l.isInteger ? l.numerator : l.floor() + 1;
  }

  /// Plays a rhythm take's phrase on the flute voice over the metronome,
  /// after a count-in, so the player hears how it goes.
  void hearTake() {
    final phrase = state.rhythmPhrase;
    if (phrase == null || !_audio.running || state.recordingSince != null) return;
    final sr = _audio.sampleRate;
    final matra = 60 / state.tempo;
    final length = _matras(phrase);
    final plan = roundClicks(
      callMatras: length,
      responseMatras: 0,
      taal: Taal.keherwa,
      metronome: true,
      countIn: true,
    );
    final origin = _audio.time + (0.3 * sr).round();
    _audio.playClicks(
      scheduleClicks(
        [
          for (final c in plan.clicks)
            if (c.matra < plan.callAt + length) c,
        ],
        start: origin,
        sampleRate: sr,
        matraSeconds: matra,
      ),
    );
    _audio.play(
      scheduleCall(
        phrase,
        saHz: state.saHz,
        start: origin + (plan.callAt * matra * sr).round(),
        sampleRate: sr,
        matraSeconds: matra,
        tuning: Tuning.just,
      ).notes,
    );
  }

  /// A rhythm take: a count-in, then the metronome through the phrase and
  /// two matras more; recording stops by itself after the last click.
  Future<void> _startRhythm(Phrase phrase) async {
    final raw = await ref.read(databaseProvider).setting('sound_delay_speaker');
    double? delayMs;
    try {
      delayMs = raw == null ? null : ((jsonDecode(raw) as Map)['ms'] as num).toDouble();
    } on Object {
      delayMs = null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (state.recordingSince == null) return;
    final sr = _audio.sampleRate;
    final matra = 60 / state.tempo;
    final plan = retryClicks(
      responseMatras: _matras(phrase) + 2,
      taal: Taal.keherwa,
      metronome: true,
      countIn: true,
    );
    final origin = _audio.time + (0.4 * sr).round();
    final clicks = scheduleClicks(plan.clicks, start: origin, sampleRate: sr, matraSeconds: matra);
    _audio.playClicks(clicks);
    _rhythm = (
      clicks: clicks,
      sam: origin + (plan.responseAt * matra * sr).round(),
      soundDelayMs: delayMs,
    );
    final end = clicks.last.time + (1.5 * sr).round();
    _autoStop = Timer(
      Duration(microseconds: ((end - _audio.time) * 1e6 / sr).round()),
      stopRecording,
    );
  }

  /// Records to `recordings/<flute>/<take>.wav`, adding -2, -3… rather than
  /// overwriting an earlier take.
  Future<void> startRecording() async {
    if (!_audio.running || state.recordingSince != null) return;
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final flute = state.flute.name.replaceAll('#', 'sharp').replaceAll(' ', '-').toLowerCase();
    final dir = Directory('${base.path}/recordings/$flute');
    await dir.create(recursive: true);
    var name = state.take.id;
    for (var n = 2; File('${dir.path}/$name.wav').existsSync(); n++) {
      name = '${state.take.id}-$n';
    }
    final path = '${dir.path}/$name.wav';
    // A take is only the player: stop a Hear it that is still playing, so
    // the flute voice and its clicks don't end up in the recording.
    _audio.stopPlayback();
    _audio.stopClicks();
    try {
      _audio.startRecording(path);
      _recordingSnapshot = state;
      _rhythm = null;
      state = state.copyWith(recordingSince: () => DateTime.now(), lastRecording: path);
      final phrase = state.rhythmPhrase;
      if (phrase != null) await _startRhythm(phrase);
    } on AudioEngineException catch (e) {
      state = state.copyWith(message: '$e');
    }
  }

  void stopRecording() {
    final path = state.lastRecording;
    if (path == null || state.recordingSince == null) return;
    _autoStop?.cancel();
    _autoStop = null;
    _audio.stopClicks();
    final start = _audio.recordingStart;
    final frames = _audio.stopRecording();
    final seconds = frames / (state.info?.sampleRate ?? 48000);
    _writeLabel(path, seconds, _recordingSnapshot ?? state, recordingStart: start);
    state = state.copyWith(
      recordingSince: () => null,
      message: 'Saved ${seconds.toStringAsFixed(1)} s',
    );
  }

  /// Label file next to the WAV (docs/07-test-fixtures.md), with the settings
  /// as they were when recording started.
  void _writeLabel(String wavPath, double seconds, DebugState s, {int? recordingStart}) {
    final info = s.info;
    String q(String v) => "'${v.replaceAll("'", "''")}'";
    final played = s.take.notes;
    final rhythm = _rhythm;
    final first = recordingStart ?? 0;
    final lines = [
      'take: ${s.take.id}',
      'flute: ${q(s.flute.name)}',
      'recorded: ${DateTime.now().toIso8601String()}',
      'seconds: ${seconds.toStringAsFixed(1)}',
      'sa_hz: ${s.saHz.toStringAsFixed(2)}',
      'sa_calibrated: ${s.calibrated}',
      'drone: ${s.droneOn}',
      'drone_volume: ${s.droneVolume.toStringAsFixed(2)}',
      'drone_first_string: ${s.firstString.name}',
      'drone_filter: ${s.highpassOn}',
      'input_preset: ${info?.inputPreset.name ?? 'unknown'}',
      'backend: ${info?.backend ?? 'unknown'}',
      'device: ${q(Platform.operatingSystemVersion)}',
      if (played != null)
        'played: ${q(played)}'
      else
        '# played: fill in the notes, docs/03 notation',
      if (s.take.countRepeats) 'count_repeats: true',
      if (s.take.rhythm != null && rhythm != null) ...[
        // Frames are samples from the start of this WAV (docs/08 M3-D).
        'rhythm: ${q(s.take.rhythm!)}',
        'taal: keherwa',
        'tempo: ${s.tempo}',
        'sam_frame: ${rhythm.sam - first}',
        'click_frames: [${rhythm.clicks.map((c) => c.time - first).join(', ')}]',
        'sound_delay_ms: ${rhythm.soundDelayMs ?? 'null'}',
      ],
      'notes: ""',
    ];
    try {
      File(
        wavPath.replaceAll(RegExp(r'\.wav$'), '.yaml'),
      ).writeAsStringSync('${lines.join('\n')}\n');
    } on FileSystemException catch (e) {
      state = state.copyWith(message: 'Saved audio, but not the label: ${e.message}');
    }
  }

  void _applyTracker() => _audio.configureFor(state.saHz, droneFilter: state.highpassOn);

  void _applyDrone() => _audio.setDrone(
    saHz: state.saHz,
    firstString: state.firstString,
    volume: state.droneVolume,
    on: state.droneOn,
  );

  void _onFrames(List<PitchFrame> frames) {
    double confidence = state.confidence, rmsDb = state.rmsDb;
    for (final f in frames) {
      final voiced = f.hz > 0 && f.confidence >= _minConfidence;
      _trace.add(voiced ? centsFromSa(f.hz, state.saHz) : null);
      confidence = f.confidence;
      rmsDb = f.rms > 0 ? 20 * math.log(f.rms) / math.ln10 : -120;
      if (voiced) {
        _unvoicedRun = 0;
        _recentHz.add(f.hz);
        if (_recentHz.length > 5) _recentHz.removeAt(0);
      } else if (++_unvoicedRun > 15) {
        _recentHz.clear();
      }
    }
    if (_trace.length > traceFrames) _trace.removeRange(0, _trace.length - traceFrames);

    double? hz;
    if (_recentHz.isNotEmpty) {
      final sorted = [..._recentHz]..sort();
      hz = sorted[sorted.length ~/ 2];
    }

    state = state.copyWith(
      hz: () => hz,
      confidence: confidence,
      rmsDb: rmsDb,
      trace: List.unmodifiable(_trace),
      info: ++_ticks % 30 == 0 ? _audio.info : null,
    );

    final calibration = _calibrator?.feed(frames);
    if (calibration != null) _finishCalibration(calibration);
  }

  void _finishCalibration(SaCalibration result) {
    _calibrator = null;
    switch (result) {
      case SaTooShort():
        state = state.copyWith(
          calibrating: false,
          message: 'Not enough steady sound. Hold Sa for the whole 3 seconds.',
        );
      case SaWrongKey(:final centsFromNominal):
        state = state.copyWith(
          calibrating: false,
          message:
              'That was ${centsFromNominal.round()} cents from ${state.flute.pitchClass.label}. '
              'Wrong flute selected?',
        );
      case SaMeasured(:final hz, :final centsFromNominal, :final spreadCents, :final steady):
        state = state.copyWith(
          calibrating: false,
          calibrated: true,
          saHz: hz,
          message:
              'Sa = ${hz.toStringAsFixed(1)} Hz '
              '(${centsFromNominal >= 0 ? '+' : ''}${centsFromNominal.toStringAsFixed(0)} c '
              'from nominal${steady ? '' : '; unsteady hold, ±${spreadCents.round()} c'})',
        );
        _applyTracker();
        _applyDrone();
    }
  }
}
