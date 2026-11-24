import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

const sr = 48000;
PitchFrame frame(double seconds, {double hz = 589, double confidence = 0.97}) =>
    PitchFrame(time: (seconds * sr).round(), hz: hz, confidence: confidence, rms: 0.05);

void main() {
  // Session 35: seven matras at 90 a minute, 4.67 s.
  const phrase = 7 * 60 / 90;

  test('waits twice the phrase plus 4 s for the player to start', () {
    final w = ListenWindow(from: 0, phraseSeconds: phrase, sampleRate: sr);
    expect(w.deadline / sr, closeTo(13.33, 0.01));
    expect(w.started, isNull);
  });

  test('never under 8 s, as listening again used to be', () {
    final w = ListenWindow(from: 0, phraseSeconds: 1.6, sampleRate: sr);
    expect(w.deadline / sr, closeTo(8, 0.01));
  });

  test('a count-in comes first', () {
    final w = ListenWindow(from: 0, phraseSeconds: phrase, sampleRate: sr, leadSeconds: 2.67);
    expect(w.deadline / sr, closeTo(16.0, 0.01));
  });

  test('a late start still gets the whole phrase', () {
    // The tries that were cut off started 4–5 s in.
    final w = ListenWindow(from: 0, phraseSeconds: phrase, sampleRate: sr)
      ..heard([frame(4.0, hz: 0, confidence: 0.2), frame(9.0)]);
    expect(w.started, 9 * sr);
    expect(w.deadline / sr, closeTo(9 + 2 * phrase + 1.5, 0.01));
    expect(w.deadline, lessThanOrEqualTo(w.latestDeadline));
  });

  test('an early start keeps the first deadline', () {
    final w = ListenWindow(from: 0, phraseSeconds: phrase, sampleRate: sr)..heard([frame(0.5)]);
    expect(w.deadline / sr, closeTo(13.33, 0.01));
  });

  test('only the first note moves it', () {
    final w = ListenWindow(from: 0, phraseSeconds: phrase, sampleRate: sr)
      ..heard([frame(5)])
      ..heard([frame(12)]);
    expect(w.started, 5 * sr);
  });

  test('unsure pitches, the drone below the flute and sound before the window are no start', () {
    final w = ListenWindow(from: sr, phraseSeconds: phrase, sampleRate: sr, minHz: 270)
      ..heard([
        frame(0.5), // before the window: the call's echo
        frame(2, confidence: 0.6),
        frame(3, hz: 260), // the drone at the tracker's floor
      ]);
    expect(w.started, isNull);
  });

  test('moves with the measured echo', () {
    final w = ListenWindow(from: 0, phraseSeconds: phrase, sampleRate: sr)..shift(sr);
    expect(w.from, sr);
    expect(w.deadline / sr, closeTo(14.33, 0.01));
  });
}
