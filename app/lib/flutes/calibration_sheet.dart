import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaroha_core/aaroha_core.dart';

import '../audio/audio_service.dart';
import '../audio/sa_calibrator.dart';
import '../data/database.dart';
import '../data/providers.dart';

/// Hold Sa for ~3 s; the result is saved to the flute's profile.
Future<void> showCalibrationSheet(BuildContext context, Flute flute) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => CalibrationSheet(flute: flute),
);

class CalibrationSheet extends ConsumerStatefulWidget {
  const CalibrationSheet({super.key, required this.flute});
  final Flute flute;

  @override
  ConsumerState<CalibrationSheet> createState() => _CalibrationSheetState();
}

class _CalibrationSheetState extends ConsumerState<CalibrationSheet> {
  SaCalibrator? _calibrator;
  SaCalibration? _result;
  StreamSubscription<List<PitchFrame>>? _frames;
  String? _error;
  double _progress = 0;

  late final AudioService _audio = ref.read(audioServiceProvider);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _result = null;
      _error = null;
      _progress = 0;
      _calibrator = SaCalibrator(widget.flute.key);
    });
    // No drone while calibrating: it would pull the ear towards the old Sa.
    _audio.setDrone(saHz: widget.flute.saHz, on: false);
    _audio.configureFor(widget.flute.key.nominalSaHz);
    if (!await _audio.ensureStarted()) {
      setState(() => _error = 'The microphone is not available (${_audio.status.name}).');
      return;
    }
    await _frames?.cancel();
    _frames = _audio.frames.listen((batch) {
      final calibrator = _calibrator;
      if (calibrator == null) return;
      final result = calibrator.feed(batch);
      setState(() {
        _progress = calibrator.progress;
        if (result != null) {
          _result = result;
          _calibrator = null;
        }
      });
    });
  }

  Future<void> _save(SaMeasured m) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.flutes)..where((f) => f.id.equals(widget.flute.id))).write(
      FlutesCompanion(calibratedSaHz: Value(m.hz), calibratedAt: Value(DateTime.now())),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _frames?.cancel();
    _audio.stop(); // the mic stays off outside calibration and practice
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final result = _result;
    final previous = widget.flute.calibratedSaHz;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Calibrate ${widget.flute.name}', style: text.titleLarge),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (result == null) ...[
              Text(
                'Play Sa with a relaxed, normal breath, the way you play it in riyaz, '
                'and hold it steadily for about 3 seconds.',
                style: text.bodyLarge,
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              Text(_progress == 0 ? 'Waiting for Sa…' : 'Listening…', style: text.bodySmall),
            ] else
              ..._resultView(result, previous, text),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultView(SaCalibration result, double? previous, TextTheme text) {
    final retry = OutlinedButton(onPressed: _start, child: const Text('Try again'));
    switch (result) {
      case SaTooShort():
        return [
          Text(
            'That was too short or too quiet. Hold Sa for the whole 3 seconds.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 16),
          retry,
        ];
      case SaWrongKey(:final centsFromNominal):
        return [
          Text(
            'That note was ${centsFromNominal.round()} cents from '
            '${widget.flute.key.pitchClass.label}. Is this the right flute, and was it Sa '
            '(three holes closed)?',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 16),
          retry,
        ];
      case SaMeasured m:
        final sign = m.centsFromNominal >= 0 ? '+' : '−';
        final change = previous == null ? null : centsFromSa(m.hz, previous);
        return [
          Text('Sa = ${m.hz.toStringAsFixed(1)} Hz', style: text.headlineMedium),
          const SizedBox(height: 4),
          Text(
            '$sign${m.centsFromNominal.abs().toStringAsFixed(0)} cents from nominal '
            '${widget.flute.key.pitchClass.label}'
            '${change == null ? '' : ' · ${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(0)} c from the saved Sa'}',
            style: text.bodyMedium,
          ),
          if (!m.steady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The note wavered by about ±${m.spreadCents.round()} cents. '
                'A steadier hold gives a better Sa.',
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: retry),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: () => _save(m), child: const Text('Save')),
              ),
            ],
          ),
        ];
    }
  }
}
