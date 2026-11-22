import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';

import '../practice/practice_settings.dart';
import 'sargam.dart';

/// Swar buttons for Listen & name (docs/08 M2-B): one per swar in the
/// session's set, with a mandra / madhya / taar switch only when the session
/// uses more than one octave.
class SwarKeypad extends StatefulWidget {
  const SwarKeypad({
    super.key,
    required this.pitches,
    required this.onTap,
    this.script = Script.latin,
    this.enabled = true,
  });

  /// Every pitch the session may ask for.
  final List<Pitch> pitches;
  final ValueChanged<Pitch> onTap;
  final Script script;
  final bool enabled;

  @override
  State<SwarKeypad> createState() => _SwarKeypadState();
}

class _SwarKeypadState extends State<SwarKeypad> {
  late int _octave = _octaves.contains(0) ? 0 : _octaves.first;

  List<int> get _octaves => {for (final p in widget.pitches) p.octave}.toList()..sort();

  @override
  Widget build(BuildContext context) {
    final octaves = _octaves;
    if (!octaves.contains(_octave)) _octave = octaves.contains(0) ? 0 : octaves.first;
    final keys = [
      for (final p in widget.pitches)
        if (p.octave == _octave) p,
    ];
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (octaves.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final o in octaves)
                  ButtonSegment(
                    value: o,
                    label: Text(switch (o) {
                      -1 => 'Mandra',
                      0 => 'Madhya',
                      _ => 'Taar',
                    }),
                  ),
              ],
              selected: {_octave},
              onSelectionChanged: (s) => setState(() => _octave = s.first),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in keys)
              SizedBox(
                width: 72,
                height: 72,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: widget.enabled ? () => widget.onTap(p) : null,
                  child: SwarGlyph(
                    p,
                    script: widget.script,
                    size: 24,
                    color: widget.enabled ? scheme.onSecondaryContainer : scheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
