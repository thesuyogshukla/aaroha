import 'dart:math' as math;

import '../model/swar.dart';
import '../model/tuning.dart';
import 'segmenter.dart';

/// Section 4 of docs/05-evaluation.md.
enum Verdict {
  /// Right swar, within tolerance.
  pass,

  /// Right swar, but flat or sharp beyond tolerance.
  outOfTune,

  /// A different swar (50 cents or more from the target).
  wrongSwar,

  /// Right swar in the wrong saptak, when the octave must match.
  wrongOctave,

  /// Nothing usable was played for this target.
  missing,

  /// A played note that matches no target.
  extra,
}

class JudgeSettings {
  const JudgeSettings({
    this.toleranceCents = 25,
    this.octaveMustMatch = true,
    this.tuning = Tuning.equal,
    this.singleMinNoteMs = 300,
    this.sampleRate = 48000,
    this.strictIntonation = false,
  });

  final double toleranceCents;
  final bool octaveMustMatch;
  final Tuning tuning;

  /// In single-swar mode, the first note at least this long is judged.
  final double singleMinNoteMs;
  final int sampleRate;

  /// When false (the default), a right swar that is out of tune still passes
  /// the attempt: Aaroha trains the ear first, and the cents are reported
  /// and tracked rather than failed (decisions.md D31). When true, every
  /// note must be within [toleranceCents].
  final bool strictIntonation;
}

class JudgedNote {
  const JudgedNote({required this.verdict, this.target, this.played, this.deviation});

  final Verdict verdict;

  /// Null for an extra note.
  final Pitch? target;

  /// Null for a missing note.
  final DetectedNote? played;

  /// Cents from the target (after the octave rule), when something was played
  /// for it.
  final double? deviation;

  /// In tune: the right swar within tolerance.
  bool get passed => verdict == Verdict.pass;

  /// The right swar, in tune or not.
  bool get rightSwar => verdict == Verdict.pass || verdict == Verdict.outOfTune;

  @override
  String toString() =>
      '${target?.ascii ?? '+'}:${verdict.name}'
      '${deviation == null ? '' : '(${deviation!.toStringAsFixed(0)}c)'}';
}

class AttemptResult {
  const AttemptResult(this.notes, {this.strictIntonation = false});

  /// One entry per target in order, with extra played notes in between.
  final List<JudgedNote> notes;

  /// See [JudgeSettings.strictIntonation].
  final bool strictIntonation;

  /// Every target matched with the right swar (and in tune, if strict), no
  /// extra notes.
  bool get passed =>
      notes.isNotEmpty && notes.every((n) => strictIntonation ? n.passed : n.rightSwar);

  /// Every note also within tolerance.
  bool get inTune => notes.isNotEmpty && notes.every((n) => n.passed);

  /// A note's attack cracked into another mode before settling (D48).
  bool get cracked => notes.any((n) => n.played?.crack != null);

  List<JudgedNote> get targets => [
    for (final n in notes)
      if (n.target != null) n,
  ];

  @override
  String toString() => '${passed ? 'PASS' : 'FAIL'} ${notes.join(' ')}';
}

/// Judges one played note against one target.
JudgedNote judgeNote(Pitch target, DetectedNote played, JudgeSettings settings) {
  var dev = played.cents - settings.tuning.centsOf(target);
  final octaves = (dev / 1200).round();
  final octaveOff = octaves != 0 && (dev - 1200 * octaves).abs() < 50;
  if (!settings.octaveMustMatch) {
    dev -= 1200 * octaves;
  } else if (octaveOff) {
    return JudgedNote(
      verdict: Verdict.wrongOctave,
      target: target,
      played: played,
      deviation: dev - 1200 * octaves,
    );
  }
  final verdict = dev.abs() <= settings.toleranceCents
      ? Verdict.pass
      : dev.abs() < 50
      ? Verdict.outOfTune
      : Verdict.wrongSwar;
  return JudgedNote(verdict: verdict, target: target, played: played, deviation: dev);
}

/// Single-swar mode: the first note of at least [JudgeSettings.singleMinNoteMs].
AttemptResult judgeSingle(Pitch target, List<DetectedNote> notes, JudgeSettings settings) {
  for (final n in notes) {
    if (n.durationMs(settings.sampleRate) >= settings.singleMinNoteMs) {
      return AttemptResult([
        judgeNote(target, n, settings),
      ], strictIntonation: settings.strictIntonation);
    }
  }
  return AttemptResult([
    JudgedNote(verdict: Verdict.missing, target: target),
  ], strictIntonation: settings.strictIntonation);
}

/// Phrase mode (pitch only): aligns played notes to targets with edit
/// distance, then judges each matched pair. A note held across an extra
/// breath (the same pitch twice in a row where the target has it once) is
/// merged first.
AttemptResult judgePhrase(List<Pitch> targets, List<DetectedNote> notes, JudgeSettings settings) {
  final played = _mergeRepeats(notes, targets);
  final n = targets.length, m = played.length;

  // Substitution costs 0 for a note within 50 c of its target (in or out of
  // tune), 1 otherwise; a missing or extra note costs 1.
  double sub(int i, int j) {
    final judged = judgeNote(targets[i], played[j], settings);
    return judged.verdict == Verdict.pass || judged.verdict == Verdict.outOfTune ? 0 : 1;
  }

  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    cost[i][0] = i.toDouble();
  }
  for (var j = 1; j <= m; j++) {
    cost[0][j] = j.toDouble();
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      cost[i][j] = math.min(
        cost[i - 1][j - 1] + sub(i - 1, j - 1),
        math.min(cost[i - 1][j] + 1, cost[i][j - 1] + 1),
      );
    }
  }

  final out = <JudgedNote>[];
  var i = n, j = m;
  // Walking back from the end: on a tie between matching this pair and
  // calling the target missing, call it missing, so that played notes match
  // the earliest targets they can ("S S R" played "S R" misses the second S).
  // A substitution still beats missing + extra.
  while (i > 0 || j > 0) {
    final diagonal = i > 0 && j > 0 && cost[i][j] == cost[i - 1][j - 1] + sub(i - 1, j - 1);
    final missing = i > 0 && cost[i][j] == cost[i - 1][j] + 1;
    if (diagonal && !(missing && sub(i - 1, j - 1) == 0)) {
      out.add(judgeNote(targets[i - 1], played[j - 1], settings));
      i--;
      j--;
    } else if (missing) {
      out.add(JudgedNote(verdict: Verdict.missing, target: targets[i - 1]));
      i--;
    } else {
      out.add(JudgedNote(verdict: Verdict.extra, played: played[j - 1]));
      j--;
    }
  }
  return AttemptResult(out.reversed.toList(), strictIntonation: settings.strictIntonation);
}

/// Merges back-to-back played notes on the same pitch, unless the targets
/// themselves repeat a pitch back to back.
List<DetectedNote> _mergeRepeats(List<DetectedNote> notes, List<Pitch> targets) {
  final targetsRepeat = [
    for (var i = 1; i < targets.length; i++) targets[i] == targets[i - 1],
  ].any((r) => r);
  if (targetsRepeat) return notes;
  final out = <DetectedNote>[];
  for (final note in notes) {
    final last = out.isEmpty ? null : out.last;
    if (last != null && last.pitch == note.pitch) {
      final longer = (last.end - last.onset) >= (note.end - note.onset) ? last : note;
      out[out.length - 1] = DetectedNote(
        pitch: note.pitch,
        onset: last.onset,
        end: note.end,
        cents: longer.cents,
        deviation: longer.deviation,
        stability: longer.stability,
        crack: last.crack ?? note.crack,
      );
    } else {
      out.add(note);
    }
  }
  return out;
}

/// Listen & name (docs/08 M2-B): judges tapped answers against the targets,
/// position by position. Each answer is treated as an exactly played note, so
/// the octave rule and hints work as in played attempts.
AttemptResult judgeNamed(List<Pitch> targets, List<Pitch> answers, JudgeSettings settings) {
  DetectedNote asPlayed(Pitch p) => DetectedNote(
    pitch: p,
    onset: 0,
    end: 0,
    cents: settings.tuning.centsOf(p),
    deviation: 0,
    stability: 0,
  );
  return AttemptResult([
    for (var i = 0; i < targets.length; i++)
      i < answers.length
          ? judgeNote(targets[i], asPlayed(answers[i]), settings)
          : JudgedNote(verdict: Verdict.missing, target: targets[i]),
    for (var i = targets.length; i < answers.length; i++)
      JudgedNote(verdict: Verdict.extra, played: asPlayed(answers[i])),
  ], strictIntonation: settings.strictIntonation);
}
