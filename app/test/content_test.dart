import 'dart:convert';

import 'package:aaroha/audio/sound_delay.dart';
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

  test('rhythm lessons load, keherwa first, each file in its order', () async {
    final content = await loadContent(rootBundle);
    final ids = content.rhythmLessons.map((l) => l.id).toList();
    expect(ids.first, 'keherwa-1');
    expect(ids.indexOf('keherwa-alankars') < ids.indexOf('dadra-1'), isTrue);
    expect(content.rhythmLesson('dadra-2')!.taal, Taal.dadra);
    expect(content.rhythmLesson('dadra-2')!.title, 'Dadra · Two swars in a matra');
  });

  test('rhythm settings: always played and clicked, stored with the lesson', () {
    final s = PracticeSettings.fromJson(
      const PracticeSettings(
        mode: PracticeMode.rhythm,
        rhythmLessonId: 'dadra-1',
        strictRhythm: true,
        answerBy: AnswerBy.name,
      ).toJson(),
    );
    expect([s.mode, s.rhythmLessonId, s.strictRhythm], [PracticeMode.rhythm, 'dadra-1', true]);
    expect(s.naming, isFalse, reason: 'rhythm is played, whatever How you answer says');
    expect(s.clicks, isTrue, reason: 'with neither the metronome nor a count-in set');
    expect(sessionLabel(jsonEncode(s.toJson())), 'rhythm, dadra 1');
    expect(const PracticeSettings().strictRhythm, isFalse);
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

  test('the pitch trace is on by default and saved with the settings', () {
    expect(const PracticeSettings().showTrace, isTrue);
    expect(
      PracticeSettings.fromJson(const PracticeSettings(showTrace: false).toJson()).showTrace,
      isFalse,
    );
  });

  test('the call tempo is 75 matras a minute unless changed', () {
    expect(const PracticeSettings().tempo, 75, reason: 'the 0.8 s per note phrases had before');
    expect(PracticeSettings.fromJson(const PracticeSettings(tempo: 60).toJson()).tempo, 60);
    expect(PracticeSettings.fromJson({'tempo': 5000}).tempo, 200);
    expect(PracticeSettings.tempos, contains(const PracticeSettings().tempo));
  });

  test('metronome settings: off by default, saved, and only for played phrases', () {
    const d = PracticeSettings();
    expect([d.metronome, d.countIn, d.taal, d.clicks], [false, false, null, false]);
    final s = PracticeSettings.fromJson(
      const PracticeSettings(
        mode: PracticeMode.raga,
        metronome: true,
        countIn: true,
        taalId: 'dadra',
        clickVolume: 0.3,
      ).toJson(),
    );
    expect([s.metronome, s.countIn, s.taal, s.clickVolume], [true, true, Taal.dadra, 0.3]);
    expect(s.clicks, isTrue);
    expect(s.copyWith(answerBy: AnswerBy.name).clicks, isFalse, reason: 'naming never clicks');
    expect(s.copyWith(mode: PracticeMode.single).clicks, isFalse, reason: 'nor a single swar');
    expect(PracticeSettings.fromJson({'taal': 'bogus'}).taal, isNull);
  });

  test('a sound delay is stored per output and read back', () {
    final d = SoundDelay(
      route: OutputRoute.speaker,
      ms: 431.26,
      spreadMs: 1.04,
      measuredAt: DateTime(2026, 11, 23, 23, 5),
    );
    final back = SoundDelay.fromJson(OutputRoute.speaker, jsonEncode(d.toJson()))!;
    expect([back.ms, back.spreadMs, back.measuredAt], [431.3, 1.0, DateTime(2026, 11, 23, 23, 5)]);
    expect(SoundDelay.key(OutputRoute.bluetooth), 'sound_delay_bluetooth');
    expect(SoundDelay.fromJson(OutputRoute.speaker, 'nonsense'), isNull);
    expect(OutputRoute.values.where((r) => r.measurable), [OutputRoute.speaker]);
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
