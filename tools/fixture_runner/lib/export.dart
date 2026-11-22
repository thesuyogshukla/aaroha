import 'dart:convert';
import 'dart:io';

import 'native.dart';
import 'session.dart';

/// Writes each attempt of a recorded session as JSON (its settings, target
/// and the tracker frames heard while listening), one file per attempt in
/// [outDir]. The app's trace preview test draws them (docs/05 §10).
bool exportAttempts(NativeCore core, String logPath, String outDir) {
  final recorded = RecordedSession.load(core, logPath);
  final header = recorded.header;
  final session = header['sessionId'];
  Directory(outDir).createSync(recursive: true);
  var count = 0;
  for (final e in recorded.judgeEvents) {
    final name = 's$session-r${e['round']}-a${e['attempt']}';
    File('$outDir/$name.json').writeAsStringSync(
      jsonEncode({
        'name': name,
        'flute': header['flute'],
        'saHz': recorded.saHz,
        'sampleRate': recorded.sampleRate,
        'settings': header['settings'],
        'target': e['target'],
        'phone': e['result'],
        'frames': [
          for (final f in recorded.heard(e))
            [
              f.time,
              double.parse(f.hz.toStringAsFixed(2)),
              double.parse(f.confidence.toStringAsFixed(3)),
              f.rms,
            ],
        ],
      }),
    );
    count++;
  }
  stdout.writeln('$count attempts written to $outDir');
  return true;
}
