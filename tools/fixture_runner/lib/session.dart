import 'dart:convert';
import 'dart:io';

import 'package:aaroha_core/aaroha_core.dart';

import 'native.dart';
import 'wav.dart';

/// A practice session saved by the app (SessionRecorder), with the tracker
/// re-run over its audio on the engine clock, so frames line up with the log.
class RecordedSession {
  RecordedSession._(
    this.path,
    this.events,
    this.header,
    this.sampleRate,
    this.seconds,
    this.frames,
  );

  /// Loads a session log and its recording, with the parts recorded after
  /// each pause (`…-session-N-part2.jsonl`, …) appended in order. Every part
  /// is stamped with the same engine clock, so they join up.
  factory RecordedSession.load(NativeCore core, String logPath) {
    final base = logPath.replaceAll(RegExp(r'\.jsonl$'), '');
    final events = <Map<String, dynamic>>[];
    final frames = <PitchFrame>[];
    var seconds = 0.0;
    var sampleRate = 48000;
    Map<String, dynamic>? header;
    for (var part = 1; ; part++) {
      final path = part == 1 ? base : '$base-part$part';
      if (!File('$path.jsonl').existsSync()) break;
      final partEvents = [
        for (final line in File('$path.jsonl').readAsLinesSync())
          if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
      ];
      final start = partEvents.firstWhere((e) => e['event'] == 'recording');
      header ??= start;
      events.addAll(partEvents);
      final wav = readWav('$path.wav');
      sampleRate = wav.sampleRate;
      seconds += wav.seconds;
      final recordStart = start['engineFrame'] as int;
      final saHz = (start['saHz'] as num).toDouble();
      frames.addAll([
        for (final f in core.analyze(
          wav.samples,
          wav.sampleRate,
          highpassHz: 0.7 * hzFromCents(-500, saHz),
          minHz: hzFromCents(-700, saHz),
        ))
          PitchFrame(time: f.time + recordStart, hz: f.hz, confidence: f.confidence, rms: f.rms),
      ]);
    }
    if (header == null) throw ArgumentError('no session log at $logPath');
    return RecordedSession._(logPath, events, header, sampleRate, seconds, frames);
  }

  final String path;
  final List<Map<String, dynamic>> events;

  /// The `recording` line: flute, Sa, settings.
  final Map<String, dynamic> header;
  final int sampleRate;
  final double seconds;
  final List<PitchFrame> frames;

  int get id => header['sessionId'] as int;
  double get saHz => (header['saHz'] as num).toDouble();
  Map<String, dynamic> get settings => header['settings'] as Map<String, dynamic>;

  // Sessions recorded before D31 have neither key: they were judged in equal
  // temperament, strictly.
  Tuning get tuning => settings['tuning'] == 'just' ? Tuning.just : Tuning.equal;

  JudgeSettings judgeSettings({Tuning? tuning, double? toleranceCents}) => JudgeSettings(
    toleranceCents: toleranceCents ?? (settings['toleranceCents'] as num).toDouble(),
    octaveMustMatch: settings['octaveMustMatch'] as bool,
    tuning: tuning ?? this.tuning,
    sampleRate: sampleRate,
    strictIntonation: settings['strictIntonation'] as bool? ?? true,
  );

  /// The phone's verdicts, in order.
  Iterable<Map<String, dynamic>> get judgeEvents => events.where((e) => e['event'] == 'judge');

  /// The frames heard while listening for [judge].
  List<PitchFrame> heard(Map<String, dynamic> judge) {
    final from = judge['listenFrom'] as int;
    final until = (judge['lastFrame'] as int?) ?? judge['t'] as int;
    return [
      for (final f in frames)
        if (f.time >= from && f.time <= until) f,
    ];
  }

  /// The notes the app would detect in [heard], in [tuning]. As the app, the
  /// floor is a semitone below the flute's lowest note: mandra Pa on every
  /// medium flute (the log does not record the range).
  List<DetectedNote> notes(List<PitchFrame> heard, {Tuning? tuning}) {
    final t = tuning ?? this.tuning;
    return segmentNotes(
      heard,
      saHz: saHz,
      tuning: t,
      config: SegmenterConfig(
        sampleRate: sampleRate,
        floorCents: t.centsOf(const Pitch(Swar.pa, -1)) - 100,
      ),
    );
  }

  /// Judges [notes] against [judge]'s target as the app would.
  AttemptResult judge(
    Map<String, dynamic> judge,
    List<DetectedNote> notes,
    JudgeSettings settings,
  ) {
    final target = parsePhrase(judge['target'] as String).pitches;
    return target.length == 1
        ? judgeSingle(target.single, notes, settings)
        : judgePhrase(target, notes, settings);
  }
}

/// Replays a practice session saved by the app (SessionRecorder): for every
/// verdict, re-runs the tracker, segmenter and judge on the same stretch of
/// audio and compares with what the phone decided. Also reports timings that
/// matter for tuning the listening window (docs/05 "Ending an attempt").
bool replaySession(NativeCore core, String logPath) {
  final session = RecordedSession.load(core, logPath);
  final header = session.header;
  final sr = session.sampleRate;
  final saHz = session.saHz;
  final tuning = session.tuning;
  final judgeSettings = session.judgeSettings();
  String secs(int frames) => (frames / sr).toStringAsFixed(2);

  stdout.writeln(
    '${header['flute']} · Sa ${saHz.toStringAsFixed(1)} Hz · '
    '${session.seconds.toStringAsFixed(0)} s of audio · tolerance ±${judgeSettings.toleranceCents} c · '
    '${tuning == Tuning.just ? 'just' : 'equal'} tuning'
    '${judgeSettings.strictIntonation ? ', strict' : ''}\n',
  );
  var agree = 0, total = 0;
  for (final e in session.judgeEvents) {
    total++;
    final from = e['listenFrom'] as int;
    final until = (e['lastFrame'] as int?) ?? e['t'] as int;
    final heard = session.heard(e);
    final notes = session.notes(heard);
    var host = session.judge(e, notes, judgeSettings);
    // Rhythm practice (D53): time the host's notes on the phone's grid.
    final grid = e['rhythm'] as Map<String, dynamic>?;
    if (grid != null) {
      host = host.withRhythm(
        judgeRhythm(
          parsePhrase(e['target'] as String),
          host,
          sams: [for (final s in grid['sams'] as List) s as int],
          matraFrames: (grid['matraFrames'] as num).toDouble(),
          delayFrames: grid['delayFrames'] as int,
          cycleMatras: Taal.byId('${session.settings['taal']}')?.matras,
        ),
      );
    }
    String timing(Object? offset) =>
        offset == null ? '' : '@${(offset as num) >= 0 ? '+' : ''}${offset.toStringAsFixed(2)}';
    final phone = [
      for (final n in e['result'] as List)
        '${n['target'] ?? '+'}:${n['verdict']}${timing(n['offset'])}',
    ].join(' ');
    var k = 0;
    final hostText = [
      for (final n in host.notes)
        '${n.target?.ascii ?? '+'}:${n.verdict.name}'
            '${timing(n.target == null ? null : host.rhythm?.notes[k++]?.offset)}',
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
    if (host.rhythm case final r?) {
      stdout.writeln(
        '    timing: ${r.count(Timing.onTime)} on time, ${r.count(Timing.early)} early, '
        '${r.count(Timing.late)} late, ${r.heldShort} held short'
        '${r.entry == 0 ? '' : ', came in ${r.entry > 0 ? '+' : ''}${r.entry} matras off'}'
        '${r.drift == null ? '' : ', ${r.drift!.name}'}'
        '${grid!['measuredDelay'] == true ? '' : ' (delay from the call\'s echo)'}',
      );
    }
    stdout.writeln(
      '    heard: ${notes.isEmpty ? 'nothing' : notes.map((n) => '${n.pitch.ascii}'
                '(${n.deviation >= 0 ? '+' : ''}${n.deviation.toStringAsFixed(0)}c, '
                '${n.durationMs(sr).toStringAsFixed(0)}ms'
                '${n.crack == null ? '' : ', cracked to ${n.crack!.ascii}'})').join(' ')}',
    );
  }
  stdout.writeln('\n$agree of $total verdicts reproduced on the host.');
  return agree == total;
}
