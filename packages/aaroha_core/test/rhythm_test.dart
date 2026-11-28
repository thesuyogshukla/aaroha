import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

const matra = 48000; // 60 a minute
const delay = 20000; // the sound delay, in frames

/// The phrase played from [sam], each note [offsets] matras off its written
/// place, held [hold] of its written length.
AttemptResult play(
  Phrase phrase, {
  required int sam,
  List<double>? offsets,
  double hold = 0.9,
  int? skip,
}) {
  final sounding = phrase.sounding;
  final notes = <DetectedNote>[
    for (var i = 0; i < sounding.length; i++)
      if (i != skip)
        () {
          final n = sounding[i];
          final onset = sam + delay + ((n.start.toDouble() + (offsets?[i] ?? 0)) * matra).round();
          final cents = Tuning.just.centsOf(n.pitch!);
          return DetectedNote(
            pitch: n.pitch!,
            onset: onset,
            end: onset + (n.duration.toDouble() * hold * matra).round(),
            cents: cents,
            deviation: 0,
            stability: 2,
          );
        }(),
  ];
  return judgePhrase(phrase.pitches, notes, const JudgeSettings(tuning: Tuning.just));
}

void main() {
  final phrase = parsePhrase('S - R G | m - P - ||');
  final sams = [100000, 100000 + 8 * matra, 100000 + 16 * matra];

  RhythmResult judge(AttemptResult r) =>
      judgeRhythm(phrase, r, sams: sams, matraFrames: matra.toDouble(), delayFrames: delay)!;

  test('notes on their written places are on time, from the sam they started on', () {
    final r = judge(play(phrase, sam: sams[1]));
    expect(r.inTime, isTrue);
    expect(r.sam, sams[1]);
    expect(r.notes.map((n) => n!.timing), everyElement(Timing.onTime));
    expect(r.drift, Drift.steady);
    expect(r.notes[0]!.held, closeTo(0.9, 1e-9), reason: 'S is written for two matras');
    expect(r.notes[1]!.held, isNull, reason: 'R is one matra: not checked as a hold');
    expect(r.matraAt(sams[1] + delay + 3 * matra), 3, reason: 'the written time line');
  });

  test('a note more than 15% of a matra off is early or late', () {
    final r = judge(play(phrase, sam: sams[0], offsets: [0, -0.2, 0.1, 0.3, 0]));
    expect(
      [for (final n in r.notes) n!.timing],
      [Timing.onTime, Timing.early, Timing.onTime, Timing.late, Timing.onTime],
    );
    expect(r.notes[1]!.offset, closeTo(-0.2, 1e-4));
    expect(r.inTime, isFalse);
    expect(r.count(Timing.early), 1);
    expect(r.count(Timing.late), 1);
  });

  test('a hold played under three quarters of its length is held too short', () {
    final r = judge(play(phrase, sam: sams[0], hold: 0.5));
    expect(r.heldShort, 3, reason: 'S, m and P are written for two matras');
    expect(r.inTime, isFalse);
  });

  test('a steadily faster player is rushing, a slower one dragging', () {
    List<double> drift(double perMatra) => [
      for (final n in phrase.sounding) n.start.toDouble() * perMatra,
    ];
    expect(judge(play(phrase, sam: sams[0], offsets: drift(-0.08))).drift, Drift.rushing);
    expect(judge(play(phrase, sam: sams[0], offsets: drift(0.08))).drift, Drift.dragging);
    expect(judge(play(phrase, sam: sams[0], offsets: drift(0.02))).drift, Drift.steady);
  });

  test('a missing note has no timing; too few notes give no drift', () {
    final r = judge(play(phrase, sam: sams[0], skip: 2));
    expect(r.notes[2], isNull);
    expect(r.notes.whereType<NoteTiming>(), hasLength(4));
    final short = parsePhrase('S R');
    final s = judgeRhythm(
      short,
      play(short, sam: sams[0]),
      sams: sams,
      matraFrames: matra.toDouble(),
      delayFrames: delay,
    )!;
    expect(s.drift, isNull);
    expect(s.inTime, isTrue);
  });

  test('strict rhythm fails a right-swar attempt that is off time; off, it passes', () {
    final r = play(phrase, sam: sams[0], offsets: [0, 0.4, 0, 0, 0]);
    final rhythm = judge(r);
    expect(r.withRhythm(rhythm).passed, isTrue);
    expect(r.withRhythm(rhythm, strict: true).passed, isFalse);
    expect(r.withRhythm(judge(play(phrase, sam: sams[0])), strict: true).passed, isTrue);
  });

  test('no sams, nothing to time', () {
    final r = play(phrase, sam: sams[0]);
    expect(
      judgeRhythm(phrase, r, sams: const [], matraFrames: matra.toDouble(), delayFrames: delay),
      isNull,
    );
  });

  test('the tempo fit finds the ratio and the offset', () {
    final fit = TempoFit.of([0, 1, 2, 3], [0.1, 1.05, 2.0, 2.95])!;
    expect(fit.tempoRatio, closeTo(1 / 0.95, 1e-9));
    expect(fit.offset, closeTo(0.1, 1e-9));
    expect(fit.driftLabel, 'rushing 5.3%');
  });

  group('where the player came in (D58)', () {
    final four = parsePhrase('S R G m');
    RhythmResult judgeFrom(Phrase p, AttemptResult r, {int? cycle}) => judgeRhythm(
      p,
      r,
      sams: sams,
      matraFrames: matra.toDouble(),
      delayFrames: delay,
      cycleMatras: cycle,
    )!;

    test('a matra late after a count-in: said once, the notes timed from there', () {
      final r = judgeFrom(four, play(four, sam: sams[0] + matra), cycle: 8);
      expect(r.entry, 1);
      expect(r.notes.map((n) => n!.timing), everyElement(Timing.onTime));
      expect(r.inTime, isFalse, reason: 'coming in wrong is a rhythm mistake');
      expect(r.sam, sams[0] + matra);
    });

    test('straight after the call instead of on the next sam: half a keherwa cycle', () {
      final r = judgeFrom(four, play(four, sam: sams[1] - 4 * matra), cycle: 8);
      expect(r.entry.abs(), 4);
      expect(r.count(Timing.onTime), 4);
    });

    test('a whole avartan late is still right', () {
      final r = judgeFrom(four, play(four, sam: sams[0] + 8 * matra), cycle: 8);
      expect([r.entry, r.inTime], [0, true]);
    });

    test('a late first note alone doesn\'t move the entry', () {
      // S comes 0.5 late and R is on time: still timed from the expected
      // start, with S late, not "came in a matra late" with R early.
      final two = parsePhrase('S - R -');
      final r = judgeFrom(two, play(two, sam: sams[0], offsets: [0.5, 0]), cycle: 8);
      expect(r.entry, 0);
      expect([r.notes[0]!.timing, r.notes[1]!.timing], [Timing.late, Timing.onTime]);
    });

    test('a steady drag of a third of a matra stays late, not a different entry', () {
      final r = judgeFrom(four, play(four, sam: sams[0], offsets: [0.3, 0.3, 0.3, 0.3]), cycle: 8);
      expect(r.entry, 0);
      expect(r.count(Timing.late), 4);
    });
  });
}
