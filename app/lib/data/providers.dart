import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../practice/practice_settings.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final flutesProvider = StreamProvider<List<Flute>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.flutes)..orderBy([(f) => OrderingTerm.asc(f.id)])).watch();
});

extension FluteProfile on Flute {
  FluteKey get key => FluteKey(PitchClass.values[pitchClass], FluteSize.values[size]);

  /// Calibrated Sa, or the nominal one until the flute is calibrated.
  double get saHz => calibratedSaHz ?? key.nominalSaHz;
  bool get calibrated => calibratedSaHz != null;
  Pitch get low => parsePhrase(rangeLow).pitches.single;
  Pitch get high => parsePhrase(rangeHigh).pitches.single;
}

/// The flute chosen on the home screen, remembered across launches.
class SelectedFlute extends AsyncNotifier<int?> {
  static const _key = 'selected_flute';

  @override
  Future<int?> build() async => int.tryParse(await ref.read(databaseProvider).setting(_key) ?? '');

  Future<void> select(int id) async {
    state = AsyncData(id);
    await ref.read(databaseProvider).setSetting(_key, '$id');
  }
}

final selectedFluteIdProvider = AsyncNotifierProvider<SelectedFlute, int?>(SelectedFlute.new);

/// The selected flute, falling back to the first one.
final selectedFluteProvider = Provider<Flute?>((ref) {
  final flutes = ref.watch(flutesProvider).value ?? const [];
  if (flutes.isEmpty) return null;
  final id = ref.watch(selectedFluteIdProvider).value;
  return flutes.firstWhere((f) => f.id == id, orElse: () => flutes.first);
});

/// Practice options, remembered across launches.
class PracticeSettingsNotifier extends AsyncNotifier<PracticeSettings> {
  static const _key = 'practice_settings';

  @override
  Future<PracticeSettings> build() async {
    final json = await ref.read(databaseProvider).setting(_key);
    if (json == null) return const PracticeSettings();
    try {
      return PracticeSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object {
      return const PracticeSettings();
    }
  }

  Future<void> save(PracticeSettings settings) async {
    state = AsyncData(settings);
    await ref.read(databaseProvider).setSetting(_key, jsonEncode(settings.toJson()));
  }
}

final practiceSettingsProvider = AsyncNotifierProvider<PracticeSettingsNotifier, PracticeSettings>(
  PracticeSettingsNotifier.new,
);
