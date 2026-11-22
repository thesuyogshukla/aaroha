import 'dart:convert';
import 'dart:io';

import 'package:aaroha_core/aaroha_core.dart';

import 'native.dart';
import 'wav.dart';

/// Writes each attempt of a recorded session as JSON (its settings, target
/// and the tracker frames heard while listening), one file per attempt in
/// [outDir]. The app's trace preview test draws them (docs/05 §10).
bool exportAttempts(NativeCore core, String logPath, String outDir) {
  final events = [
    for (final line in File(logPath).readAsLinesSync())
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
  ];
  final header = events.firstWhere((e) => e['event'] == 'recording');
  final wav = readWav(logPath.replaceAll(RegExp(r'\.jsonl$'), '.wav'));
  final recordStart = header['engineFrame'] as int;
  final saHz = (header['saHz'] as num).toDouble();
  final frames = [
    for (final f in core.analyze(
      wav.samples,
      wav.sampleRate,
      highpassHz: 0.7 * hzFromCents(-500, saHz),
      minHz: hzFromCents(-700, saHz),
    ))
      PitchFrame(time: f.time + recordStart, hz: f.hz, confidence: f.confidence, rms: f.rms),
  ];
  final session = header['sessionId'];
  Directory(outDir).createSync(recursive: true);
  var count = 0;
  for (final e in events.where((e) => e['event'] == 'judge')) {
    final from = e['listenFrom'] as int;
    final until = (e['lastFrame'] as int?) ?? e['t'] as int;
    final name = 's$session-r${e['round']}-a${e['attempt']}';
    File('$outDir/$name.json').writeAsStringSync(
      jsonEncode({
        'name': name,
        'flute': header['flute'],
        'saHz': saHz,
        'sampleRate': wav.sampleRate,
        'settings': header['settings'],
        'target': e['target'],
        'phone': e['result'],
        'frames': [
          for (final f in frames)
            if (f.time >= from && f.time <= until)
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
