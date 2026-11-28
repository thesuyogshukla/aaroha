import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../data/tunes.dart';
import '../practice/practice_settings.dart';
import '../widgets/sargam.dart';

/// Your tunes (D56): the tunes typed in on this phone, newest change first.
class TunesScreen extends ConsumerWidget {
  const TunesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunes = ref.watch(tunesProvider);
    void edit(StoredTune? tune) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => TuneEditorScreen(tune: tune)));
    return Scaffold(
      appBar: AppBar(title: const Text('Your tunes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Add a tune'),
      ),
      body: tunes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Type in a bandish, a gat or any tune in sargam, and practise it line by '
                    'line. Your tunes stay on this phone.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final t in list)
                    ListTile(
                      title: Text(t.title),
                      subtitle: Text(_describe(t)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => edit(t),
                    ),
                ],
              ),
      ),
    );
  }

  static String _describe(StoredTune t) {
    final tune = t.parsed;
    if (tune == null) return 'Needs fixing before it can be practised';
    final n = tune.lines.length;
    return [
      '$n ${n == 1 ? 'line' : 'lines'}',
      if (tune.taal != null)
        tune.start == 0 ? tune.taal!.label : '${tune.taal!.label} from matra ${tune.start + 1}',
      if (tune.header['raga'] != null) 'raga ${tune.header['raga']}',
    ].join(' · ');
  }
}

/// Adding or changing a tune: a title and its notation, checked as you type,
/// with each line drawn as it will be shown in practice.
class TuneEditorScreen extends ConsumerStatefulWidget {
  const TuneEditorScreen({super.key, this.tune});

  /// Null for a new tune.
  final StoredTune? tune;

  @override
  ConsumerState<TuneEditorScreen> createState() => _TuneEditorScreenState();
}

class _TuneEditorScreenState extends ConsumerState<TuneEditorScreen> {
  late final _title = TextEditingController(text: widget.tune?.title ?? '');
  late final _notation = TextEditingController(text: widget.tune?.notation ?? '');

  static const _example = 'taal: keherwa\n\nS - R G | m - G R\nG m P - | m G R S';

  @override
  void dispose() {
    _title.dispose();
    _notation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(practiceSettingsProvider).value ?? const PracticeSettings();
    final flute = ref.watch(selectedFluteProvider);
    final result = parseTune(_title.text, _notation.text);
    final tune = result.tune;
    // Before anything is typed, no problems are shown yet.
    final untouched = _notation.text.trim().isEmpty && _title.text.trim().isEmpty;
    final outOfRange = tune == null || flute == null
        ? const <int>[]
        : linesOutOfRange(tune, low: flute.low, high: flute.high, tuning: settings.tuning.tuning);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tune == null ? 'New tune' : 'Edit tune'),
        actions: [
          if (widget.tune != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: tune == null ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notation,
            decoration: const InputDecoration(
              labelText: 'Notation',
              hintText: _example,
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
            minLines: 6,
            maxLines: null,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'One line of the tune per row, matras separated by spaces: "-" holds, "_" rests, '
            'two swars in a matra share it, | and || are bars. Komal: r g d n; tivra Ma: M; '
            "mandra .N; taar S'. A taal line at the top (taal: teentaal) times the tune, and a "
            'start line (start: 9) says which matra each line begins on, 1 being sam.',
            style: theme.textTheme.bodySmall,
          ),
          if (!untouched && result.problems.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final p in result.problems)
              Text(
                '$p${p.column > 1 ? ' (column ${p.column})' : ''}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
          ],
          if (tune != null) ...[
            const SizedBox(height: 16),
            Text(tuneTiming(tune), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < tune.lines.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: theme.textTheme.bodySmall)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: PhraseSargam(tune.lines[i], script: settings.script, size: 24),
                          ),
                          if (outOfRange.contains(i + 1))
                            Text(
                              'Beyond ${flute!.name}: left out of practice on this flute',
                              style: TextStyle(color: theme.colorScheme.tertiary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final id = await saveTune(
      db,
      id: widget.tune?.id,
      title: _title.text,
      notation: _notation.text,
    );
    // A new tune becomes the one Your tunes practises.
    if (widget.tune == null) {
      final notifier = ref.read(practiceSettingsProvider.notifier);
      final s = ref.read(practiceSettingsProvider).value;
      if (s != null) await notifier.save(s.copyWith(tuneId: id));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${widget.tune!.title}"?'),
        content: const Text(
          'The tune is removed from this phone. Past sessions keep their rounds.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    await deleteTune(ref.read(databaseProvider), widget.tune!.id);
    if (mounted) Navigator.of(context).pop();
  }
}
