// Draws timed phrases with the app's sargam widget to a PNG sheet, to check
// how rhythm reads without a phone (docs/08 M3-A). Skipped unless set:
//
//   AAROHA_NOTATION_OUT  the PNG file to write
//
// AAROHA_NOTATION_OUT=… FLUTTER_ROOT=… flutter test test/notation_preview_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:aaroha/practice/practice_settings.dart';
import 'package:aaroha/widgets/sargam.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _out = Platform.environment['AAROHA_NOTATION_OUT'];

const _phrases = [
  'S R G m',
  'S - RG m | P - DP mG ||',
  "G - - R | S .D S R | G _ P G | D P G R ||",
  'SRGm PDNS\' S\'NDP mGRS',
  'S-R G , m P _',
  'G m d - , d P , G m r - , r S',
];

Future<void> _loadFonts() async {
  final root = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    final file = File('$root/Roboto-$w.ttf');
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
  // Devanagari, if the Mac has it.
  const devanagari = '/System/Library/Fonts/Supplemental/DevanagariMT.ttc';
  final kohinoor = File('/System/Library/Fonts/Kohinoor.ttc');
  for (final path in [devanagari, kohinoor.path]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final dl = FontLoader('Devanagari')
      ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await dl.load();
    break;
  }
}

void main() {
  testWidgets('notation preview sheet', (tester) async {
    if (_out == null) return;
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    ThemeData theme(Brightness b) => ThemeData(
      colorSchemeSeed: const Color(0xFF8D5A2B),
      brightness: b,
      useMaterial3: true,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Devanagari'],
    );
    Widget column(Brightness b, Script script) => Theme(
      data: theme(b),
      child: Builder(
        builder: (context) => Container(
          width: 550,
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final text in _phrases) ...[
                Text(
                  text,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 6),
                PhraseSargam(parsePhrase(text), script: script, size: 30),
                const SizedBox(height: 18),
              ],
              Text(
                'verdict colours',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 6),
              PhraseSargam(
                parsePhrase('S - RG m'),
                script: script,
                size: 30,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                  Theme.of(context).colorScheme.error,
                  Theme.of(context).colorScheme.primary,
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: Material(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                column(Brightness.light, Script.latin),
                column(Brightness.dark, Script.devanagari),
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
      File(_out!).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
