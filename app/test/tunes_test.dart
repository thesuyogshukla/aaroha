import 'dart:convert';

import 'package:aaroha/data/database.dart';
import 'package:aaroha/data/providers.dart';
import 'package:aaroha/data/tunes.dart';
import 'package:aaroha/practice/practice_settings.dart';
import 'package:aaroha/tunes/tunes_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the chosen tune is saved with the settings', () {
    final s = PracticeSettings.fromJson(
      const PracticeSettings(mode: PracticeMode.tune, tuneId: 7).toJson(),
    );
    expect([s.mode, s.tuneId], [PracticeMode.tune, 7]);
    expect(PracticeSettings.fromJson(const PracticeSettings().toJson()).tuneId, isNull);
    expect(sessionLabel(jsonEncode(s.toJson())), 'your tune');
  });

  testWidgets('typing a tune shows its problems, then its lines, and saves it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TuneEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.widgetWithText(TextButton, 'Save');
    expect(tester.widget<TextButton>(save).onPressed, isNull, reason: 'nothing typed yet');

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Evening tune');
    await tester.enterText(find.widgetWithText(TextField, 'Notation'), 'S R X G');
    await tester.pumpAndSettle();
    expect(find.textContaining('Line 1:'), findsOneWidget);
    expect(tester.widget<TextButton>(save).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Notation'),
      "taal: keherwa\nS - R G | m - G R\nP D N S' D'",
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.textContaining('left out of practice'),
      findsOneWidget,
      reason: "taar Dha is beyond taar Pa",
    );

    // The database runs on the test's clock: pump until the save is done.
    await tester.tap(save);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final read = db.select(db.tunes).get();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final stored = await read;
    expect(stored.single.title, 'Evening tune');
    expect(stored.single.parsed!.lines, hasLength(2));
    expect(stored.single.parsed!.header['taal'], 'keherwa');

    // Close the screen so the database's streams stop, then let their
    // clean-up timers run.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('saving again changes the tune; deleting removes it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await saveTune(db, title: 'A', notation: 'S R');
    await saveTune(db, id: id, title: ' B ', notation: 'G m');
    final t = (await db.select(db.tunes).get()).single;
    expect([t.title, t.notation], ['B', 'G m']);
    await deleteTune(db, id);
    expect(await db.select(db.tunes).get(), isEmpty);
  });
}
