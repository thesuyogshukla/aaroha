// Fixture runner: checks the native pitch tracker and the core segmenter on
// synthetic signals and on labelled recordings (docs/07-test-fixtures.md).
//
//   dart run bin/fixture_runner.dart selftest
//   dart run bin/fixture_runner.dart analyze <file.wav> [--sa <hz> | --flute "G medium"] [--highpass]
//   dart run bin/fixture_runner.dart check [fixtures dir]
//   dart run bin/fixture_runner.dart session <recordings/sessions/…-session-N.jsonl>
//   dart run bin/fixture_runner.dart export <…-session-N.jsonl> <dir>   (attempts for trace previews)
//   dart run bin/fixture_runner.dart clickcheck [dir]   (the fixtures with metronome clicks mixed in)
//   dart run bin/fixture_runner.dart intonation <…-session-N.jsonl>... [--csv <file>]
//
// Exit code is non-zero when a required check fails.

import 'dart:io';
import 'dart:math' as math;

import 'package:fixture_runner/native.dart';
import 'package:fixture_runner/session.dart';
import 'package:fixture_runner/export.dart';
import 'package:fixture_runner/intonation.dart';
import 'package:fixture_runner/synth.dart';
import 'package:fixture_runner/wav.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:yaml/yaml.dart';

const sampleRate = 48000;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: fixture_runner selftest | analyze <wav> [...] | check [dir] | clickcheck [dir] | '
      'session <log.jsonl> '
      '| export <log.jsonl> <dir> | intonation <log.jsonl>... [--csv <file>]',
    );
    exit(64);
  }
  final core = NativeCore.open();
  final ok = switch (args.first) {
    'selftest' => selftest(core),
    'analyze' => analyze(core, args.skip(1).toList()),
    'check' => check(core, args.length > 1 ? args[1] : '${repoRoot()}/fixtures'),
    'clickcheck' => clickCheck(core, args.length > 1 ? args[1] : '${repoRoot()}/fixtures'),
    'session' => replaySession(core, args[1]),
    'export' => exportAttempts(core, args[1], args[2]),
    'intonation' => intonationReport(core, [
      for (final (i, a) in args.indexed.skip(1))
        if (a != '--csv' && args[i - 1] != '--csv') a,
    ], csvPath: args.contains('--csv') ? args[args.indexOf('--csv') + 1] : null),
    _ => throw ArgumentError('unknown command ${args.first}'),
  };
  exit(ok ? 0 : 1);
}

/// High-pass cutoff the app uses: 0.7 × the flute's lowest note (mandra Pa).
double highpassFor(double saHz) => 0.7 * hzFromCents(-500, saHz);

/// Lowest pitch searched: two semitones below mandra Pa. The drone's strings
/// all sit below this, so drone-only audio has no period in range.
double minHzFor(double saHz) => hzFromCents(-700, saHz);

// ---------------------------------------------------------------- selftest

class _Condition {
  const _Condition(
    this.name, {
    this.droneDb,
    this.highpass = true,
    this.limitRange = true,
    this.required = true,
  });
  final String name;
  final double? droneDb;
  final bool highpass;
  final bool limitRange;
  final bool required;
}

/// Drone cases are informational until the real speaker-to-mic bleed level is
/// measured on a phone (decisions.md D17).
const _conditions = [
  _Condition('clean, full range', highpass: false, limitRange: false),
  _Condition('clean, app config'),
  _Condition('drone −12 dB, app config', droneDb: -12, required: false),
  _Condition('drone −6 dB, app config', droneDb: -6, required: false),
  _Condition('drone 0 dB, app config', droneDb: 0, required: false),
  _Condition('drone +6 dB, app config', droneDb: 6, required: false),
  _Condition('drone 0 dB, range only', droneDb: 0, highpass: false, required: false),
  _Condition('drone 0 dB, filter only', droneDb: 0, limitRange: false, required: false),
];

/// Every chromatic pitch from mandra Pa to taar Pa, with a repeating pattern
/// of deliberate detunes (cents) to check that deviations are measured.
const _detunes = [0.0, 20.0, -30.0, 8.0, -12.0];

bool selftest(NativeCore core) {
  final targets = [for (var c = -500; c <= 1900; c += 100) c.toDouble()];
  final detunes = [for (var i = 0; i < targets.length; i++) _detunes[i % _detunes.length]];
  final notes = [for (var i = 0; i < targets.length; i++) SynthNote(targets[i] + detunes[i])];

  stdout.writeln(
    'Synthetic self-test: ${targets.length} notes per flute (.P to P\'), '
    'detunes ${_detunes.map((d) => d.toStringAsFixed(0)).join('/')} c\n',
  );
  stdout.writeln(
    '${'condition'.padRight(24)}${'flute'.padRight(11)}'
    '${'notes'.padLeft(7)}${'xtra'.padLeft(4)}${'dev err max'.padLeft(13)}${'mean'.padLeft(7)}'
    '${'voiced'.padLeft(8)}${'gross'.padLeft(7)}  result',
  );

  var allOk = true;
  for (final condition in _conditions) {
    for (final flute in ownerFlutes) {
      final sa = flute.nominalSaHz;
      final synth = synthesize(notes, sa, sampleRate);
      var samples = synth.samples;
      if (condition.droneDb != null) {
        final drone = core.renderDrone(sa, sampleRate, samples.length);
        samples = mix(samples, drone, condition.droneDb!);
      }
      final frames = core.analyze(
        samples,
        sampleRate,
        highpassHz: condition.highpass ? highpassFor(sa) : 0,
        minHz: condition.limitRange ? minHzFor(sa) : null,
      );
      final detected = segmentNotes(frames, saHz: sa);

      // Note level: right sequence, deviations measured correctly.
      final expected = [for (final c in targets) Tuning.equal.nearest(c).pitch];
      final pairs = _align(expected, [for (final n in detected) n.pitch]);
      final matched = pairs.length;
      final extra = detected.length - matched;
      final devErrors = [for (final (e, d) in pairs) (detected[d].deviation - detunes[e]).abs()];
      final sequenceOk = matched == expected.length && extra == 0;

      // Frame level, inside each note's steady part.
      var inside = 0, voiced = 0, gross = 0;
      for (final f in frames) {
        for (var i = 0; i < synth.spans.length; i++) {
          final (start, end) = synth.spans[i];
          if (f.time < start + 0.12 * sampleRate || f.time > end - 0.06 * sampleRate) continue;
          inside++;
          if (f.hz > 0 && f.confidence >= 0.85) {
            voiced++;
            final err = centsFromSa(f.hz, sa) - (targets[i] + detunes[i]);
            if (err.abs() > 600) gross++;
          }
        }
      }

      final maxErr = devErrors.isEmpty ? double.nan : devErrors.reduce(math.max);
      final meanErr = devErrors.isEmpty
          ? double.nan
          : devErrors.reduce((a, b) => a + b) / devErrors.length;
      final voicedPct = inside == 0 ? 0.0 : 100 * voiced / inside;
      final grossPct = voiced == 0 ? 0.0 : 100 * gross / voiced;
      final pass = sequenceOk && maxErr < 5 && grossPct < 1 && voicedPct > 95;
      if (condition.required && !pass) allOk = false;

      stdout.writeln(
        '${condition.name.padRight(24)}${flute.name.padRight(11)}'
        '${'$matched/${expected.length}'.padLeft(7)}${'+$extra'.padLeft(4)}'
        '${maxErr.toStringAsFixed(1).padLeft(13)}${meanErr.toStringAsFixed(1).padLeft(7)}'
        '${'${voicedPct.toStringAsFixed(0)}%'.padLeft(8)}'
        '${'${grossPct.toStringAsFixed(1)}%'.padLeft(7)}  '
        '${pass
            ? 'PASS'
            : condition.required
            ? 'FAIL'
            : 'info'}',
      );
      if (!sequenceOk && condition.required) {
        stdout.writeln('    expected ${expected.join(' ')}');
        stdout.writeln('    detected ${detected.map((n) => n.pitch).join(' ')}');
      }
    }
  }
  if (!_voiceSelftest(core, targets)) allOk = false;
  if (!_clickSelftest(core, targets, detunes)) allOk = false;
  stdout.writeln('\n${allOk ? 'All required checks passed.' : 'Some required checks FAILED.'}');
  return allOk;
}

/// The app's own flute voice (the "call") must play every note in tune: the
/// tracker reads it back within 2 cents on every flute.
bool _voiceSelftest(NativeCore core, List<double> targets) {
  stdout.writeln('\nFlute voice: every note .P to P\', 600 ms each, read back by the tracker');
  var ok = true;
  for (final flute in ownerFlutes) {
    final sa = flute.nominalSaHz;
    final notes = [
      for (var i = 0; i < targets.length; i++)
        VoiceNote(
          i * 0.7 * sampleRate ~/ 1,
          (0.6 * sampleRate).round(),
          hzFromCents(targets[i], sa),
        ),
    ];
    final audio = core.renderNotes(
      notes,
      sampleRate,
      (targets.length * 0.7 + 0.5) * sampleRate ~/ 1,
    );
    final detected = segmentNotes(
      core.analyze(audio, sampleRate, highpassHz: highpassFor(sa), minHz: minHzFor(sa)),
      saHz: sa,
    );
    final expected = [for (final c in targets) Tuning.equal.nearest(c).pitch];
    final sequenceOk = _listEquals(expected, [for (final n in detected) n.pitch]);
    final worst = detected.isEmpty
        ? double.nan
        : detected.map((n) => n.deviation.abs()).reduce(math.max);
    final pass = sequenceOk && worst < 2;
    if (!pass) ok = false;
    stdout.writeln(
      '  ${flute.name.padRight(11)} ${detected.length}/${expected.length} notes, '
      'worst ${worst.toStringAsFixed(2)} c  ${pass ? 'PASS' : 'FAIL'}',
    );
  }
  return ok;
}

/// A click track: one click every [matraSeconds], cycling through every
/// kind of matra, from 50 ms in.
List<(int, Beat)> _clickTrack(int length, double matraSeconds) => [
  for (var k = 0; (0.05 + k * matraSeconds) * sampleRate < length; k++)
    (((0.05 + k * matraSeconds) * sampleRate).round(), Beat.values[k % Beat.values.length]),
];

/// Metronome clicks (docs/08 M3-B) must never read as notes, and must not
/// change what the tracker hears in the flute: alone at the fastest tempo
/// offered, and over the synthetic notes at 75 matras a minute, from 12 dB
/// below the flute's peak to 6 dB above it.
bool _clickSelftest(NativeCore core, List<double> targets, List<double> detunes) {
  stdout.writeln('\nMetronome clicks alone, 110 a minute, full level: no notes allowed');
  var ok = true;
  for (final flute in ownerFlutes) {
    final sa = flute.nominalSaHz;
    final length = 20 * sampleRate;
    final audio = core.renderClicks(_clickTrack(length, 60 / 110), sampleRate, length);
    final frames = core.analyze(
      audio,
      sampleRate,
      highpassHz: highpassFor(sa),
      minHz: minHzFor(sa),
    );
    final voiced = frames.where((f) => f.hz > 0 && f.confidence >= 0.85).length;
    final notes = segmentNotes(frames, saHz: sa);
    final pass = notes.isEmpty;
    if (!pass) ok = false;
    stdout.writeln(
      '  ${flute.name.padRight(11)} ${notes.length} notes, $voiced voiced frames of '
      '${frames.length}  ${pass ? 'PASS' : 'FAIL'}',
    );
  }

  stdout.writeln(
    '\nClicks over the synthetic notes, 75 a minute (level: click peak vs flute peak)',
  );
  final notes = [for (var i = 0; i < targets.length; i++) SynthNote(targets[i] + detunes[i])];
  final expected = [for (final c in targets) Tuning.equal.nearest(c).pitch];
  for (final level in [-12.0, -6.0, 0.0, 6.0]) {
    for (final flute in ownerFlutes) {
      final sa = flute.nominalSaHz;
      final synth = synthesize(notes, sa, sampleRate);
      final clicks = core.renderClicks(
        _clickTrack(synth.samples.length, 0.8),
        sampleRate,
        synth.samples.length,
      );
      final samples = mixPeak(synth.samples, clicks, level);
      final frames = core.analyze(
        samples,
        sampleRate,
        highpassHz: highpassFor(sa),
        minHz: minHzFor(sa),
      );
      final detected = segmentNotes(frames, saHz: sa);
      final pairs = _align(expected, [for (final n in detected) n.pitch]);
      final extra = detected.length - pairs.length;
      final devErrors = [for (final (e, d) in pairs) (detected[d].deviation - detunes[e]).abs()];
      final maxErr = devErrors.isEmpty ? double.nan : devErrors.reduce(math.max);
      final pass = pairs.length == expected.length && extra == 0 && maxErr < 5;
      if (!pass) ok = false;
      stdout.writeln(
        '  ${'${level >= 0 ? '+' : ''}${level.toStringAsFixed(0)} dB'.padRight(7)}'
        '${flute.name.padRight(11)} ${pairs.length}/${expected.length} notes, +$extra, '
        'dev err max ${maxErr.toStringAsFixed(1)} c  ${pass ? 'PASS' : 'FAIL'}',
      );
      if (!pass) {
        stdout.writeln('      detected ${detected.map((n) => n.pitch).join(' ')}');
      }
    }
  }
  return ok;
}

// ---------------------------------------------------------------- analyze

bool analyze(NativeCore core, List<String> args) {
  if (args.isEmpty) throw ArgumentError('analyze needs a WAV path');
  final wav = readWav(args.first);
  double? sa = _option(args, '--sa') == null ? null : double.parse(_option(args, '--sa')!);
  final fluteName = _option(args, '--flute');
  if (fluteName != null) sa ??= _flute(fluteName).nominalSaHz;
  final highpass = args.contains('--highpass');

  final frames = core.analyze(wav.samples, wav.sampleRate);
  sa ??= _measureSa(frames);
  final filtered = highpass
      ? core.analyze(wav.samples, wav.sampleRate, highpassHz: highpassFor(sa), minHz: minHzFor(sa))
      : frames;
  final notes = segmentNotes(
    filtered,
    saHz: sa,
    config: SegmenterConfig(sampleRate: wav.sampleRate),
  );

  final voiced = filtered.where((f) => f.hz > 0 && f.confidence >= 0.85).length;
  stdout.writeln(
    '${args.first}: ${wav.seconds.toStringAsFixed(1)} s @ ${wav.sampleRate} Hz, '
    '${filtered.length} frames, ${(100 * voiced / filtered.length).toStringAsFixed(0)}% voiced',
  );
  stdout.writeln('Sa ${sa.toStringAsFixed(2)} Hz${highpass ? ', drone filter on' : ''}\n');
  for (final n in notes) {
    final at = (n.onset / wav.sampleRate).toStringAsFixed(2).padLeft(7);
    final ms = n.durationMs(wav.sampleRate).toStringAsFixed(0).padLeft(5);
    stdout.writeln(
      '$at s  ${n.pitch.ascii.padRight(4)} $ms ms  '
      '${n.deviation >= 0 ? '+' : ''}${n.deviation.toStringAsFixed(1)} c  '
      '±${n.stability.toStringAsFixed(1)}',
    );
  }
  stdout.writeln('\nSequence: ${notes.map((n) => n.pitch.ascii).join(' ')}');
  return true;
}

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

FluteKey _flute(String name) => ownerFlutes.firstWhere(
  (f) => f.name.toLowerCase() == name.toLowerCase().replaceAll('-', ' ').replaceAll('sharp', '#'),
  orElse: () => throw ArgumentError('unknown flute "$name"'),
);

/// Median pitch of the confidently voiced frames: for a Sa-hold take.
double _measureSa(List<PitchFrame> frames) {
  final hz = [
    for (final f in frames)
      if (f.hz > 0 && f.confidence >= 0.9) f.hz,
  ]..sort();
  if (hz.isEmpty) throw StateError('no pitched sound to measure Sa from');
  return hz[hz.length ~/ 2];
}

// ---------------------------------------------------------------- check

/// Parses the `played:` line of a fixture label into pitches. Annotations in
/// parentheses ("G(flat)") and phrase breaks are ignored.
List<Pitch> _parsePlayed(String played) => [
  for (final token in played.replaceAll(RegExp(r'\([^)]*\)'), '').split(RegExp(r'[\s,]+')))
    if (token.isNotEmpty)
      Pitch(
        Swar.fromAscii(token.replaceAll('.', '').replaceAll("'", '')),
        "'".allMatches(token).length - '.'.allMatches(token).length,
      ),
];

/// The labelled recordings again with metronome clicks mixed in at 75 a
/// minute, at several levels against the flute's peak: clicks must not
/// change a single note (docs/08 M3-B).
bool clickCheck(NativeCore core, String dir) {
  var ok = true;
  for (final level in [-6.0, 0.0, 6.0]) {
    stdout.writeln('\nClicks at ${level >= 0 ? '+' : ''}${level.toStringAsFixed(0)} dB:');
    if (!check(core, dir, clicksDb: level)) ok = false;
  }
  return ok;
}

bool check(NativeCore core, String dir, {double? clicksDb}) {
  final labels = Directory(dir).existsSync()
      ? (Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.yaml'))
            // Unreviewed phone pulls live in raw/; check them only when asked.
            .where((f) => dir.contains('/raw') || !f.path.substring(dir.length).contains('/raw/'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  if (labels.isEmpty) {
    stdout.writeln('No labelled fixtures in $dir yet (see docs/07-test-fixtures.md).');
    return true;
  }

  var allOk = true;
  for (final label in labels) {
    final yaml = loadYaml(label.readAsStringSync()) as YamlMap;
    final wavPath = label.path.replaceAll(RegExp(r'\.yaml$'), '.wav');
    if (!File(wavPath).existsSync() || yaml['played'] == null) continue;

    final wav = readWav(wavPath);
    final sa = _fixtureSa(core, label, yaml);
    final highpass = (yaml['drone_filter'] ?? yaml['drone']) == true;
    final samples = clicksDb == null
        ? wav.samples
        : mixPeak(
            wav.samples,
            core.renderClicks(
              _clickTrack(wav.samples.length, 0.8),
              wav.sampleRate,
              wav.samples.length,
            ),
            clicksDb,
          );
    final frames = core.analyze(
      samples,
      wav.sampleRate,
      highpassHz: highpass ? highpassFor(sa) : 0,
      minHz: highpass ? minHzFor(sa) : null,
    );
    // As the app: nothing more than a semitone below mandra Pa (D37).
    final notes = segmentNotes(
      frames,
      saHz: sa,
      config: SegmenterConfig(sampleRate: wav.sampleRate, floorCents: -600),
    );
    // A long note that splits in two is not a mismatch unless the take is
    // about repeated notes (docs/05 phrase judging merges them the same way).
    final countRepeats = yaml['count_repeats'] == true;
    final expected = _collapse(_parsePlayed('${yaml['played']}'), countRepeats);
    final got = _collapse([for (final n in notes) n.pitch], countRepeats);
    final ok = _listEquals(expected, got);
    if (!ok) allOk = false;
    stdout.writeln('${ok ? 'PASS' : 'FAIL'}  ${label.path.substring(dir.length + 1)}');
    if (!ok) {
      stdout.writeln('      expected ${expected.join(' ')}');
      stdout.writeln('      detected ${got.join(' ')}');
    }
  }
  return allOk;
}

/// `sa_hz:` from the label when it was calibrated, else measured from the
/// flute's sa-hold take, else the flute's nominal Sa.
double _fixtureSa(NativeCore core, File label, YamlMap yaml) {
  if (yaml['sa_hz'] is num && yaml['sa_calibrated'] != false) {
    return (yaml['sa_hz'] as num).toDouble();
  }
  final saHold = File('${label.parent.path}/sa-hold.wav');
  if (saHold.existsSync()) {
    final wav = readWav(saHold.path);
    return _measureSa(core.analyze(wav.samples, wav.sampleRate));
  }
  return _flute('${yaml['flute']}').nominalSaHz;
}

/// Longest common subsequence of [expected] and [detected], as index pairs.
List<(int, int)> _align(List<Pitch> expected, List<Pitch> detected) {
  final n = expected.length, m = detected.length;
  final table = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      table[i][j] = expected[i] == detected[j]
          ? table[i + 1][j + 1] + 1
          : math.max(table[i + 1][j], table[i][j + 1]);
    }
  }
  final pairs = <(int, int)>[];
  for (var i = 0, j = 0; i < n && j < m;) {
    if (expected[i] == detected[j]) {
      pairs.add((i++, j++));
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return pairs;
}

bool _listEquals(List<Pitch> a, List<Pitch> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Drops back-to-back repeats of the same pitch unless [keep].
List<Pitch> _collapse(List<Pitch> pitches, bool keep) => keep
    ? pitches
    : [
        for (var i = 0; i < pitches.length; i++)
          if (i == 0 || pitches[i] != pitches[i - 1]) pitches[i],
      ];
