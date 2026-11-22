import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../audio/audio_service.dart';

/// Saves a practice session's raw mic audio plus a JSON-lines log of what the
/// app did and when (calls, listening windows, verdicts), so a session can be
/// replayed on the host with `fixture_runner session` (docs/07).
///
/// Files: `recordings/sessions/<flute>-session-<id>[-partN].wav` and `.jsonl`.
/// Every log line carries `t`, the engine frame when it was written. The
/// `recording` line's `engineFrame` is the engine frame of (roughly, within a
/// few tens of ms) the WAV's first sample. Pausing closes a part; resuming
/// starts the next one.
///
/// Both files stay readable if the app is killed mid-session: log lines go
/// straight to the file (a few per round), and the native writer keeps the
/// WAV header current to within a second.
class SessionRecorder {
  SessionRecorder(this._audio);

  final AudioService _audio;
  String? _base;
  RandomAccessFile? _log;
  int _part = 0;
  Map<String, Object?> _header = const {};

  bool get active => _log != null;

  Future<void> start(String flute, int sessionId, Map<String, Object?> header) async {
    final root = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/recordings/sessions');
    await dir.create(recursive: true);
    final slug = flute.replaceAll('#', 'sharp').replaceAll(' ', '-').toLowerCase();
    _base = '${dir.path}/$slug-session-$sessionId';
    _header = header;
    _part = 0;
    await resume();
  }

  /// Opens the next part (after a pause, or the first one).
  Future<void> resume() async {
    final base = _base;
    if (base == null || active) return;
    _part++;
    final path = _part == 1 ? base : '$base-part$_part';
    try {
      _audio.startRecording('$path.wav');
    } on Object {
      return; // the session goes on without audio
    }
    _log = File('$path.jsonl').openSync(mode: FileMode.write);
    log('recording', {
      'part': _part,
      'engineFrame': _audio.time,
      'sampleRate': _audio.sampleRate,
      ..._header,
    });
  }

  void log(String event, [Map<String, Object?> fields = const {}]) =>
      _log?.writeStringSync('${jsonEncode({'event': event, 't': _audio.time, ...fields})}\n');

  Future<void> pause() async {
    final log = _log;
    if (log == null) return;
    this.log('paused');
    _log = null;
    _audio.stopRecording();
    log.closeSync();
  }

  Future<void> stop() async {
    await pause();
    _base = null;
  }
}
