import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'calibration_sheet.dart';

/// Flute profiles: choose, calibrate, add, edit (docs/02-music-model.md).
class FlutesScreen extends ConsumerWidget {
  const FlutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flutes = ref.watch(flutesProvider).value ?? const [];
    final selected = ref.watch(selectedFluteProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Flutes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editFlute(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add flute'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final f in flutes)
            ListTile(
              leading: Icon(
                f.id == selected?.id ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              title: Text(f.name),
              subtitle: Text(
                f.calibrated
                    ? 'Sa ${f.saHz.toStringAsFixed(1)} Hz · calibrated ${_date(f.calibratedAt!)}'
                    : 'Sa ${f.saHz.toStringAsFixed(1)} Hz · not calibrated',
              ),
              onTap: () => ref.read(selectedFluteIdProvider.notifier).select(f.id),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Calibrate Sa',
                    icon: const Icon(Icons.tune),
                    onPressed: () => showCalibrationSheet(context, f),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editFlute(context, ref, f),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _editFlute(BuildContext context, WidgetRef ref, Flute? flute) async {
    final result = await showDialog<_FluteEdit>(
      context: context,
      builder: (_) => _FluteDialog(flute: flute),
    );
    if (result == null) return;
    final db = ref.read(databaseProvider);
    final companion = FlutesCompanion(
      name: Value(result.name),
      pitchClass: Value(result.key.pitchClass.index),
      size: Value(result.key.size.index),
      rangeLow: Value(result.low),
      rangeHigh: Value(result.high),
    );
    if (flute == null) {
      final id = await db.into(db.flutes).insert(companion);
      await ref.read(selectedFluteIdProvider.notifier).select(id);
    } else {
      final keyChanged =
          result.key.pitchClass.index != flute.pitchClass || result.key.size.index != flute.size;
      await (db.update(db.flutes)..where((f) => f.id.equals(flute.id))).write(
        keyChanged
            ? companion.copyWith(calibratedSaHz: const Value(null), calibratedAt: const Value(null))
            : companion,
      );
    }
  }
}

class _FluteEdit {
  const _FluteEdit(this.name, this.key, this.low, this.high);
  final String name;
  final FluteKey key;
  final String low;
  final String high;
}

class _FluteDialog extends StatefulWidget {
  const _FluteDialog({this.flute});
  final Flute? flute;

  @override
  State<_FluteDialog> createState() => _FluteDialogState();
}

class _FluteDialogState extends State<_FluteDialog> {
  late PitchClass _pitchClass = widget.flute?.key.pitchClass ?? PitchClass.e;
  late FluteSize _size = widget.flute?.key.size ?? FluteSize.medium;
  late final _name = TextEditingController(text: widget.flute?.name ?? '');
  late final _low = TextEditingController(text: widget.flute?.rangeLow ?? '.P');
  late final _high = TextEditingController(text: widget.flute?.rangeHigh ?? "P'");
  String? _error;

  @override
  Widget build(BuildContext context) {
    final key = FluteKey(_pitchClass, _size);
    return AlertDialog(
      title: Text(widget.flute == null ? 'Add flute' : 'Edit flute'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<PitchClass>(
                    initialValue: _pitchClass,
                    decoration: const InputDecoration(labelText: 'Key (Sa)'),
                    items: [
                      for (final p in PitchClass.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (p) => setState(() => _pitchClass = p!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<FluteSize>(
                    initialValue: _size,
                    decoration: const InputDecoration(labelText: 'Size'),
                    items: [
                      for (final s in FluteSize.values)
                        DropdownMenuItem(value: s, child: Text(s.name)),
                    ],
                    onChanged: (s) => setState(() => _size = s!),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: 'Name', hintText: key.name),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _low,
                    decoration: const InputDecoration(labelText: 'Lowest note'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _high,
                    decoration: const InputDecoration(labelText: 'Highest note'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nominal Sa ${key.nominalSaHz.toStringAsFixed(1)} Hz. Range in sargam, e.g. .P and P\'.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    final low = parseNotation(_low.text.trim());
    final high = parseNotation(_high.text.trim());
    if (!low.ok ||
        low.phrase!.pitches.length != 1 ||
        !high.ok ||
        high.phrase!.pitches.length != 1) {
      setState(() => _error = 'Write each end of the range as one swar, e.g. .P');
      return;
    }
    final key = FluteKey(_pitchClass, _size);
    final name = _name.text.trim().isEmpty ? key.name : _name.text.trim();
    Navigator.pop(context, _FluteEdit(name, key, _low.text.trim(), _high.text.trim()));
  }
}
