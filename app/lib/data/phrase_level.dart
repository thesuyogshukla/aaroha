import 'dart:convert';

import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';

/// The phrase level grows separately for playing and for naming: naming a
/// phrase is easier than playing it back, so it shouldn't raise the bar for
/// the flute (docs/05 §9).
String _key(bool naming) => naming ? 'phrase_level_name' : 'phrase_level_play';

Future<PhraseLevelTracker> loadPhraseLevel(AppDatabase db, {required bool naming}) async {
  final raw = await db.setting(_key(naming));
  if (raw == null) return PhraseLevelTracker();
  try {
    return PhraseLevelTracker.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } on Object {
    return PhraseLevelTracker();
  }
}

Future<void> savePhraseLevel(AppDatabase db, PhraseLevelTracker tracker, {required bool naming}) =>
    db.setSetting(_key(naming), jsonEncode(tracker.toJson()));

/// The current level for playing (false) or naming (true).
final phraseLevelProvider = FutureProvider.autoDispose.family<PhraseLevelTracker, bool>(
  (ref, naming) => loadPhraseLevel(ref.watch(databaseProvider), naming: naming),
);
