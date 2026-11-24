import 'dart:io';

import 'package:aaroha_core/aaroha_core.dart';

import 'native.dart';
import 'session.dart';

/// One right-swar note from a recorded session: what was asked, where it was
/// played, measured against both reference tunings.
class IntonationNote {
  const IntonationNote({
    required this.session,
    required this.round,
    required this.attempt,
    required this.mode,
    required this.phraseLength,
    required this.index,
    required this.pitch,
    required this.cents,
    required this.durationMs,
    required this.stability,
  });

  final int session, round, attempt;
  final String mode;
  final int phraseLength, index;
  final Pitch pitch;

  /// Median cents from Sa over the note's stable part.
  final double cents;
  final double durationMs;

  /// Standard deviation of cents over the stable part.
  final double stability;

  double deviation(Tuning tuning) => cents - tuning.centsOf(pitch);
}

/// Reads every session and collects the notes judged the right swar (in tune
/// or not), as the app judges them.
List<IntonationNote> collectIntonation(NativeCore core, List<String> logPaths) {
  final out = <IntonationNote>[];
  // A later part is read with its session's first part.
  for (final path in logPaths.where((p) => !RegExp(r'-part\d+\.jsonl$').hasMatch(p))) {
    final s = RecordedSession.load(core, path);
    final settings = s.judgeSettings();
    for (final e in s.judgeEvents) {
      final result = s.judge(e, s.notes(s.heard(e)), settings);
      final targets = result.targets;
      for (var i = 0; i < targets.length; i++) {
        final n = targets[i];
        if (!n.rightSwar) continue;
        out.add(
          IntonationNote(
            session: s.id,
            round: e['round'] as int,
            attempt: e['attempt'] as int,
            mode: s.settings['mode'] as String? ?? 'single',
            phraseLength: targets.length,
            index: i,
            pitch: n.target!,
            cents: n.played!.cents,
            durationMs: n.played!.durationMs(s.sampleRate),
            stability: n.played!.stability,
          ),
        );
      }
    }
  }
  return out;
}

double _percentile(List<double> values, double p) {
  if (values.isEmpty) return double.nan;
  final sorted = [...values]..sort();
  final at = (sorted.length - 1) * p;
  final lo = at.floor(), hi = at.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (at - lo);
}

double _median(List<double> v) => _percentile(v, 0.5);

String _signed(double c) =>
    c.isNaN ? '   –' : '${c >= 0 ? '+' : ''}${c.toStringAsFixed(0)}'.padLeft(4);

String _pct(int n, int of) => of == 0 ? '  –' : '${(100 * n / of).round()}%'.padLeft(4);

/// Prints how far the player's right-swar notes sit from each swar, to set
/// the tolerance defaults (decisions.md, open questions). Optionally writes
/// every note to [csvPath] for further digging.
bool intonationReport(NativeCore core, List<String> logPaths, {String? csvPath}) {
  final notes = collectIntonation(core, logPaths);
  const tolerances = [10, 15, 20, 25, 30, 35, 40];
  final tunings = {'just': Tuning.just, 'equal': Tuning.equal};
  final sessions = {for (final n in notes) n.session}.toList()..sort();
  stdout.writeln(
    '${notes.length} right-swar notes from ${sessions.length} sessions '
    '(${sessions.first}–${sessions.last}).\n',
  );

  // 1. Within each tolerance, by reference tuning.
  stdout.writeln('Share of right-swar notes within ±T cents:');
  stdout.writeln('          ${tolerances.map((t) => '±$t'.padLeft(5)).join()}   median |dev|');
  for (final MapEntry(key: name, value: tuning) in tunings.entries) {
    final abs = [for (final n in notes) n.deviation(tuning).abs()];
    stdout.writeln(
      '  ${name.padRight(7)} '
      '${tolerances.map((t) => _pct(abs.where((d) => d <= t).length, abs.length).padLeft(5)).join()}'
      '   ${_median(abs).toStringAsFixed(1)} c',
    );
  }

  // 2. Per swar: where it sits (median, signed) and how much it moves.
  stdout.writeln(
    '\nPer swar (just tuning; equal in brackets). Median and middle half of the signed '
    'deviation, cents:',
  );
  final pitches = {for (final n in notes) n.pitch}.toList()
    ..sort((a, b) => Tuning.equal.centsOf(a).compareTo(Tuning.equal.centsOf(b)));
  for (final p in pitches) {
    final mine = notes.where((n) => n.pitch == p).toList();
    final dev = [for (final n in mine) n.deviation(Tuning.just)];
    final devEq = [for (final n in mine) n.deviation(Tuning.equal)];
    stdout.writeln(
      '  ${p.ascii.padRight(3)} n=${'${mine.length}'.padLeft(3)}  '
      'median ${_signed(_median(dev))} (${_signed(_median(devEq))})  '
      'middle half ${_signed(_percentile(dev, 0.25))} to ${_signed(_percentile(dev, 0.75))}  '
      'within ±25: ${_pct(dev.where((d) => d.abs() <= 25).length, dev.length)}  '
      'steadiness ±${_median([for (final n in mine) n.stability]).toStringAsFixed(1)}',
    );
  }

  // 3. By session: is it getting closer?
  stdout.writeln('\nBy session (just tuning):');
  for (final id in sessions) {
    final mine = notes.where((n) => n.session == id).toList();
    final abs = [for (final n in mine) n.deviation(Tuning.just).abs()];
    final signed = [for (final n in mine) n.deviation(Tuning.just)];
    stdout.writeln(
      '  session ${'$id'.padLeft(2)} ${mine.first.mode.padRight(8)} n=${'${mine.length}'.padLeft(3)}  '
      'median |dev| ${_median(abs).toStringAsFixed(0).padLeft(2)} c  '
      'median ${_signed(_median(signed))}  '
      'within ±25: ${_pct(abs.where((d) => d <= 25).length, abs.length)}',
    );
  }

  // 4. Splits that might call for different defaults.
  void split(String title, Map<String, bool Function(IntonationNote)> groups) {
    stdout.writeln('\n$title (just tuning):');
    for (final MapEntry(key: name, value: test) in groups.entries) {
      final abs = [
        for (final n in notes)
          if (test(n)) n.deviation(Tuning.just).abs(),
      ];
      stdout.writeln(
        '  ${name.padRight(22)} n=${'${abs.length}'.padLeft(3)}  '
        'median |dev| ${_median(abs).toStringAsFixed(0).padLeft(2)} c  '
        '90th ${_percentile(abs, 0.9).toStringAsFixed(0).padLeft(2)} c  '
        '${tolerances.map((t) => '±$t ${_pct(abs.where((d) => d <= t).length, abs.length)}').join('  ')}',
      );
    }
  }

  split('First try or not', {
    'first try': (n) => n.attempt == 1,
    'later tries': (n) => n.attempt > 1,
  });
  split('Single swar or phrase', {
    'single swar': (n) => n.phraseLength == 1,
    'in a phrase': (n) => n.phraseLength > 1,
  });
  split('How long the note was held', {
    'under 400 ms': (n) => n.durationMs < 400,
    '400–800 ms': (n) => n.durationMs >= 400 && n.durationMs < 800,
    '800 ms or more': (n) => n.durationMs >= 800,
  });

  if (csvPath != null) {
    File(csvPath).writeAsStringSync(
      [
        'session,round,attempt,mode,phrase_length,index,pitch,cents,dev_just,dev_equal,'
            'duration_ms,stability',
        for (final n in notes)
          [
            n.session,
            n.round,
            n.attempt,
            n.mode,
            n.phraseLength,
            n.index,
            n.pitch.ascii,
            n.cents.toStringAsFixed(1),
            n.deviation(Tuning.just).toStringAsFixed(1),
            n.deviation(Tuning.equal).toStringAsFixed(1),
            n.durationMs.toStringAsFixed(0),
            n.stability.toStringAsFixed(1),
          ].join(','),
      ].join('\n'),
    );
    stdout.writeln('\n${notes.length} notes written to $csvPath');
  }
  return true;
}
