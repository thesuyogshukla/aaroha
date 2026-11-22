import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

const sa = 392.0;

/// Frames at 100 per second from (cents, ms) segments; null is silence.
List<PitchFrame> frames(List<(double?, int)> segments) {
  final out = <PitchFrame>[];
  var time = 48000; // one second in
  for (final (cents, ms) in segments) {
    for (var i = 0; i < ms ~/ 10; i++) {
      out.add(
        PitchFrame(
          time: time,
          hz: cents == null ? 0 : hzFromCents(cents, sa),
          confidence: cents == null ? 0.2 : 0.97,
          rms: cents == null ? 0.0001 : 0.1,
        ),
      );
      time += 480;
    }
  }
  return out;
}

List<Pitch> ps(String ascii) => parsePhrase(ascii).pitches;

void main() {
  test('a phrase: one line per stretch of playing, notes with their verdicts', () {
    final heard = frames([(null, 300), (0, 600), (null, 100), (530, 600), (null, 300)]);
    final notes = segmentNotes(heard, saHz: sa);
    final result = judgePhrase(ps('S G'), notes, const JudgeSettings());
    final trace = buildPitchTrace(heard, result, ps('S G'), saHz: sa);

    expect(trace.lines, hasLength(2), reason: 'the silence breaks the line');
    expect(trace.lines.first.first.seconds, closeTo(0.2, 1e-9), reason: 'padded start');
    expect(trace.lanes.map((l) => l.pitch), ps('S G'));
    expect(trace.notes.map((n) => n.judged.verdict), [Verdict.pass, Verdict.wrongSwar]);
    expect(trace.noteAt(0.5)!.judged.target, ps('S').single);
    expect(trace.noteAt(1.2)!.judged.played!.pitch, ps('m').single, reason: 'played Ma for Ga');
    expect(trace.low, closeTo(-60, 1e-9));
    expect(trace.high, closeTo(590, 1e-6));
    expect(trace.duration, closeTo(0.2 + 1.3 - 0.01 + 0.2, 1e-9));
  });

  test('a single note gets at least 400 c of range; stray frames are left out', () {
    final heard = frames([(-650, 100), (null, 100), (700, 600)]);
    final result = judgeSingle(
      ps('P').single,
      segmentNotes(heard, saHz: sa),
      const JudgeSettings(),
    );
    final trace = buildPitchTrace(heard, result, ps('P'), saHz: sa);
    expect(trace.high - trace.low, closeTo(400, 1e-9));
    expect(trace.low, closeTo(500, 1e-9));
    expect(trace.lines, hasLength(1), reason: 'the stray -650 c stretch is out of range');
  });

  test('repeated target swars share one lane', () {
    final heard = frames([(0, 500), (null, 100), (0, 500)]);
    final result = judgePhrase(ps('S S'), segmentNotes(heard, saHz: sa), const JudgeSettings());
    expect(buildPitchTrace(heard, result, ps('S S'), saHz: sa).lanes, hasLength(1));
  });

  test('nothing played: lanes only', () {
    final heard = frames([(null, 500)]);
    final result = judgeSingle(ps('P').single, const [], const JudgeSettings());
    final trace = buildPitchTrace(heard, result, ps('P'), saHz: sa);
    expect(trace.isEmpty, isTrue);
    expect(trace.lanes.single.cents, 700);
    expect(trace.low, 500);
  });

  test('lanes follow the tuning', () {
    final heard = frames([(1088, 500)]);
    final result = judgeSingle(
      ps('N').single,
      segmentNotes(heard, saHz: sa, tuning: Tuning.just),
      const JudgeSettings(tuning: Tuning.just),
    );
    final trace = buildPitchTrace(heard, result, ps('N'), saHz: sa, tuning: Tuning.just);
    expect(trace.lanes.single.cents, closeTo(1088.27, 0.01));
  });
}
