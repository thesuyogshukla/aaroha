import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:aaroha_core/aaroha_core.dart';

part 'database.g.dart';

/// Flute profiles (docs/02-music-model.md).
class Flutes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// [PitchClass.index] of Sa.
  IntColumn get pitchClass => integer()();

  /// [FluteSize.index].
  IntColumn get size => integer()();
  RealColumn get calibratedSaHz => real().nullable()();
  DateTimeColumn get calibratedAt => dateTime().nullable()();

  /// Playable range in ASCII notation.
  TextColumn get rangeLow => text().withDefault(const Constant('.P'))();
  TextColumn get rangeHigh => text().withDefault(const Constant("P'"))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fluteId => integer().references(Flutes, #id)();
  TextColumn get mode => text()();

  /// The practice settings used, as JSON.
  TextColumn get settingsJson => text()();
  RealColumn get saHz => real()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
}

class Rounds extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get number => integer()();

  /// The target in ASCII notation.
  TextColumn get target => text()();
}

class Attempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get roundId => integer().references(Rounds, #id)();
  IntColumn get number => integer()();
  BoolColumn get passed => boolean()();

  /// Per-note verdicts as JSON (see AttemptRecord).
  TextColumn get resultJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Tunes the player typed in (docs/06, Compositions; D56). Kept on the phone
/// only: a tune may be someone else's work, so it is never shipped or shared.
@DataClassName('StoredTune')
class Tunes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  /// The tune as typed: an optional header, then one line per row (docs/03).
  TextColumn get notation => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Simple key/value settings.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Flutes, Sessions, Rounds, Attempts, Settings, Tunes])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'aaroha'));

  @override
  /// 1: M0–M3. 2: tunes (D56).
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Start with the owner's flutes (CLAUDE.md); they can be edited later.
      for (final key in ownerFlutes) {
        await into(flutes).insert(
          FlutesCompanion.insert(
            name: key.name,
            pitchClass: key.pitchClass.index,
            size: key.size.index,
          ),
        );
      }
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(tunes);
    },
  );

  Future<String?> setting(String key) async =>
      (await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}
