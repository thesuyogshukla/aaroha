import 'dart:convert';

import 'package:aaroha/data/content.dart';
import 'package:aaroha/data/database.dart';
import 'package:aaroha/data/phrase_level.dart';
import 'package:aaroha/practice/practice_settings.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  phraseLevelTests();

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

void phraseLevelTests() {
  test('phrase length grows by default and is saved with the settings', () {
    expect(const PracticeSettings().phraseLevelGrows, isTrue);
    final held = PracticeSettings.fromJson(const PracticeSettings(phraseLevel: 3).toJson());
    expect(held.phraseLevel, 3);
    expect(PracticeSettings.fromJson({'phraseLevel': 99}).phraseLevel, PhraseLevel.top);
  });

  test('the phrase level is stored apart for playing and naming', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect((await loadPhraseLevel(db, naming: false)).level, 1, reason: 'starts at 2–4 notes');
    final t = PhraseLevelTracker();
    for (var i = 0; i < 10; i++) {
      t.add(true);
    }
    await savePhraseLevel(db, t, naming: false);
    expect((await loadPhraseLevel(db, naming: false)).level, 2);
    expect((await loadPhraseLevel(db, naming: true)).level, 1);
    await db.setSetting('phrase_level_name', 'not json');
    expect((await loadPhraseLevel(db, naming: true)).level, 1);
  });
}
