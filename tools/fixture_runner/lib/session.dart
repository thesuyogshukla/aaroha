import 'dart:convert';
import 'dart:io';

import 'package:aaroha_core/aaroha_core.dart';

import 'native.dart';
import 'wav.dart';

/// Replays a practice session saved by the app (SessionRecorder): for every
/// verdict, re-runs the tracker, segmenter and judge on the same stretch of
/// audio and compares with what the phone decided. Also reports timings that
/// matter for tuning the listening window (docs/05 "Ending an attempt").
bool replaySession(NativeCore core, String logPath) {
  final events = [
    for (final line in File(logPath).readAsLinesSync())
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
  ];
  final header = events.firstWhere((e) => e['event'] == 'recording');
  const lowestNote = Pitch(Swar.pa, -1);
  final wav = readWav(logPath.replaceAll(RegExp(r'\.jsonl$'), '.wav'));
  final sr = wav.sampleRate;
  final recordStart = header['engineFrame'] as int;
  final saHz = (header['saHz'] as num).toDouble();
  final settings = header['settings'] as Map<String, dynamic>;
  // Sessions recorded before D31 have neither key: they were judged in equal
  // temperament, strictly.
  final tuning = settings['tuning'] == 'just' ? Tuning.just : Tuning.equal;
  final judgeSettings = JudgeSettings(
    toleranceCents: (settings['toleranceCents'] as num).toDouble(),
    octaveMustMatch: settings['octaveMustMatch'] as bool,
    tuning: tuning,
    sampleRate: sr,
    strictIntonation: settings['strictIntonation'] as bool? ?? true,
  );

  // Frames on the engine clock, so they line up with the log.
  final frames = [
    for (final f in core.analyze(
      wav.samples,
      sr,
      highpassHz: 0.7 * hzFromCents(-500, saHz),
      minHz: hzFromCents(-700, saHz),
    ))
      PitchFrame(time: f.time + recordStart, hz: f.hz, confidence: f.confidence, rms: f.rms),
  ];
  String secs(int frames) => (frames / sr).toStringAsFixed(2);

  stdout.writeln(
    '${header['flute']} · Sa ${saHz.toStringAsFixed(1)} Hz · '
    '${wav.seconds.toStringAsFixed(0)} s of audio · tolerance ±${judgeSettings.toleranceCents} c · '
    '${tuning == Tuning.just ? 'just' : 'equal'} tuning'
    '${judgeSettings.strictIntonation ? ', strict' : ''}\n',
  );
  var agree = 0, total = 0;
  for (final e in events.where((e) => e['event'] == 'judge')) {
    total++;
    final from = e['listenFrom'] as int;
    final until = (e['lastFrame'] as int?) ?? e['t'] as int;
    final heard = [
      for (final f in frames)
        if (f.time >= from && f.time <= until) f,
    ];
    final notes = segmentNotes(
      heard,
      saHz: saHz,
      tuning: tuning,
      // As the app: a semitone below the flute's lowest note, mandra Pa on
      // every medium flute (the log does not record the range).
      config: SegmenterConfig(sampleRate: sr, floorCents: tuning.centsOf(lowestNote) - 100),
    );
    final target = parsePhrase(e['target'] as String).pitches;
    final host = target.length == 1
        ? judgeSingle(target.single, notes, judgeSettings)
        : judgePhrase(target, notes, judgeSettings);
    final phone = [
      for (final n in e['result'] as List) '${n['target'] ?? '+'}:${n['verdict']}',
    ].join(' ');
    final hostText = [
      for (final n in host.notes) '${n.target?.ascii ?? '+'}:${n.verdict.name}',
    ].join(' ');
    final same = phone == hostText;
    if (same) agree++;

    final voiced = heard.where((f) => f.hz > 0 && f.confidence >= 0.85).toList();
    final reaction = voiced.isEmpty ? null : voiced.first.time - from;
    final tail = voiced.isEmpty ? null : until - voiced.last.time;
    stdout.writeln(
      'round ${e['round']} try ${e['attempt']}: ${e['target']}  '
      '${e['passed'] == true ? 'PASS' : 'FAIL'}  '
      '(listened ${secs(until - from)} s; started after ${reaction == null ? '–' : '${secs(reaction)} s'}; '
      'judged ${tail == null ? '–' : '${secs(tail)} s'} after the last note)',
    );
    stdout.writeln('    phone: $phone');
    if (!same) stdout.writeln('    host:  $hostText   ← differs');
    stdout.writeln(
      '    heard: ${notes.isEmpty ? 'nothing' : notes.map((n) => '${n.pitch.ascii}'
                '(${n.deviation >= 0 ? '+' : ''}${n.deviation.toStringAsFixed(0)}c, '
                '${n.durationMs(sr).toStringAsFixed(0)}ms)').join(' ')}',
    );
  }
  stdout.writeln('\n$agree of $total verdicts reproduced on the host.');
  return agree == total;
}
