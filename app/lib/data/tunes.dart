import 'package:aaroha_core/aaroha_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';

/// The player's tunes, most recently changed first (D56).
final tunesProvider = StreamProvider<List<StoredTune>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tunes)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
});

extension StoredTuneParsed on StoredTune {
  /// The tune as practice uses it; null if the stored text no longer parses.
  Tune? get parsed => parseTune(title, notation).tune;
}

/// Saves a tune: a new one when [id] is null. Returns its id.
Future<int> saveTune(
  AppDatabase db, {
  int? id,
  required String title,
  required String notation,
}) async {
  final now = DateTime.now();
  if (id == null) {
    return db
        .into(db.tunes)
        .insert(
          TunesCompanion.insert(
            title: title.trim(),
            notation: notation,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  await (db.update(db.tunes)..where((t) => t.id.equals(id))).write(
    TunesCompanion(title: Value(title.trim()), notation: Value(notation), updatedAt: Value(now)),
  );
  return id;
}

Future<void> deleteTune(AppDatabase db, int id) =>
    (db.delete(db.tunes)..where((t) => t.id.equals(id))).go();
