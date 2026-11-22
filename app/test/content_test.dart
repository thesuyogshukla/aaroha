import 'dart:convert';

import 'package:aaroha/data/content.dart';
import 'package:aaroha/practice/practice_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled content loads, ragas in starter order', () async {
    final content = await loadContent(rootBundle);
    expect(content.ragas.map((r) => r.id), ragaOrder);
    expect(content.alankars, hasLength(7));
    expect(content.raga('yaman')!.name, 'Yaman');
    expect(content.raga('nope'), isNull);
  });

  test('alankar and raga choices survive a save and load', () {
    const s = PracticeSettings(
      mode: PracticeMode.alankar,
      alankarId: 'alankar-5',
      alankarScale: 'kafi',
      ragaId: 'des',
    );
    final back = PracticeSettings.fromJson(s.toJson());
    expect(back.mode, PracticeMode.alankar);
    expect(back.alankarId, 'alankar-5');
    expect(back.alankarScale, 'kafi');
    expect(back.ragaId, 'des');
  });

  test('which raga a session uses', () {
    expect(const PracticeSettings(mode: PracticeMode.raga, ragaId: 'des').ragaInUse, 'des');
    expect(
      const PracticeSettings(mode: PracticeMode.alankar, alankarScale: 'yaman').ragaInUse,
      'yaman',
    );
    expect(
      const PracticeSettings(mode: PracticeMode.alankar, alankarScale: 'shuddha').ragaInUse,
      isNull,
    );
    expect(const PracticeSettings(ragaId: 'des').ragaInUse, isNull, reason: 'single swar');
  });

  test('History labels', () {
    String label(PracticeSettings s) => sessionLabel(jsonEncode(s.toJson()));
    expect(label(const PracticeSettings()), 'single swar');
    expect(label(const PracticeSettings(mode: PracticeMode.raga, ragaId: 'yaman')), 'raga Yaman');
    expect(
      label(
        const PracticeSettings(
          mode: PracticeMode.alankar,
          alankarScale: 'kafi',
          answerBy: AnswerBy.name,
        ),
      ),
      'alankar in Kafi · named',
    );
    expect(sessionLabel(jsonEncode({'mode': 'phrase'})), 'phrases');
  });
}
