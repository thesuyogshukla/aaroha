// Draws pitch traces of real attempts to PNG sheets, to check how the trace
// looks without a phone (docs/05 §10). Skipped unless both are set:
//
//   AAROHA_TRACE_IN   a folder of attempts from `fixture_runner export`
//   AAROHA_TRACE_OUT  where to write one sheet per session
//
// AAROHA_TRACE_IN=… AAROHA_TRACE_OUT=… flutter test test/trace_preview_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aaroha/practice/practice_settings.dart';
import 'package:aaroha/widgets/pitch_trace.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _in = Platform.environment['AAROHA_TRACE_IN'];
final _out = Platform.environment['AAROHA_TRACE_OUT'];

/// One recorded attempt, judged again on the host as the app would.
({String name, String target, AttemptResult result, PitchTrace trace, PracticeSettings settings})
_attempt(File file) {
  final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final settings = PracticeSettings.fromJson(j['settings'] as Map<String, dynamic>);
  final saHz = (j['saHz'] as num).toDouble();
  final sr = j['sampleRate'] as int;
  final frames = [
    for (final f in j['frames'] as List)
      PitchFrame(
        time: f[0] as int,
        hz: (f[1] as num).toDouble(),
        confidence: (f[2] as num).toDouble(),
        rms: (f[3] as num).toDouble(),
      ),
  ];
  final tuning = settings.tuning.tuning;
  final config = SegmenterConfig(
    sampleRate: sr,
    floorCents: tuning.centsOf(const Pitch(Swar.pa, -1)) - 100,
  );
  final notes = segmentNotes(frames, saHz: saHz, tuning: tuning, config: config);
  final target = parsePhrase(j['target'] as String).pitches;
  final judge = settings.judge(sr);
  final result = target.length == 1
      ? judgeSingle(target.single, notes, judge)
      : judgePhrase(target, notes, judge);
  final trace = buildPitchTrace(frames, result, target, saHz: saHz, tuning: tuning, config: config);
  return (
    name: j['name'] as String,
    target: j['target'] as String,
    result: result,
    trace: trace,
    settings: settings,
  );
}

Future<void> _loadFonts() async {
  final root = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    final file = File('$root/Roboto-$w.ttf');
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  testWidgets('trace preview sheets', (tester) async {
    if (_in == null || _out == null) return;
    await tester.runAsync(_loadFonts);
    final files = Directory(
      _in!,
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final bySession = <String, List<File>>{};
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      bySession.putIfAbsent(name.split('-').first, () => []).add(f);
    }
    int order(File f) {
      final m = RegExp(r'-r(\d+)-a(\d+)').firstMatch(f.path)!;
      return int.parse(m[1]!) * 100 + int.parse(m[2]!);
    }

    for (final entry in bySession.entries) {
      final attempts = [
        for (final f in entry.value..sort((a, b) => order(a) - order(b))) _attempt(f),
      ];
      const cellWidth = 360.0, cellHeight = 210.0;
      final rows = (attempts.length / 2).ceil();
      tester.view.physicalSize = Size(cellWidth * 2, cellHeight * rows);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      final theme = ThemeData(
        colorSchemeSeed: const Color(0xFF8D5A2B),
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Roboto',
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: RepaintBoundary(
            key: key,
            child: Material(
              child: Wrap(
                children: [
                  for (final a in attempts)
                    SizedBox(
                      width: cellWidth,
                      height: cellHeight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${a.name}  ${a.target}  ${a.result.passed ? 'PASS' : 'FAIL'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              a.result.notes.join(' '),
                              style: const TextStyle(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: PitchTraceView(
                                a.trace,
                                script: Script.latin,
                                toleranceCents: a.settings.toleranceCents,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/${entry.key}.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    addTearDown(tester.view.reset);
  });
}
