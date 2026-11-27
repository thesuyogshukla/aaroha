import 'dart:io';

import 'package:aaroha/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a version 1 database gains the tunes table and keeps its sessions', () async {
    final dir = await Directory.systemTemp.createTemp('aaroha_db');
    final file = File('${dir.path}/aaroha.sqlite');
    addTearDown(() => dir.delete(recursive: true));

    // Make a database as version 1 had it: no tunes table, a session in it.
    var db = AppDatabase(NativeDatabase(file));
    final fluteId = (await db.select(db.flutes).get()).first.id;
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            fluteId: fluteId,
            mode: 'phrase',
            settingsJson: '{}',
            saHz: 392,
            startedAt: DateTime(2026, 11, 20),
          ),
        );
    await db.customStatement('DROP TABLE tunes');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.select(db.sessions).get(), hasLength(1), reason: 'sessions kept');
    expect(await db.select(db.flutes).get(), hasLength(8), reason: 'flutes not seeded twice');
    final id = await db
        .into(db.tunes)
        .insert(
          TunesCompanion.insert(
            title: 'Evening tune',
            notation: 'S R G m',
            createdAt: DateTime(2026, 11, 28),
            updatedAt: DateTime(2026, 11, 28),
          ),
        );
    expect(
      (await (db.select(db.tunes)..where((t) => t.id.equals(id))).getSingle()).title,
      'Evening tune',
    );
  });
}
