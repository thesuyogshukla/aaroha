import 'package:aaroha_core/aaroha_core.dart';

/// One note of the flute voice, in engine frames.
class ScheduledNote {
  const ScheduledNote({
    required this.start,
    required this.duration,
    required this.hz,
    this.glideToHz,
    this.amplitude = 0.5,
  });

  final int start;
  final int duration;
  final double hz;
  final double? glideToHz;
  final double amplitude;
}

class ScheduledCall {
  const ScheduledCall(this.notes, this.end);
  final List<ScheduledNote> notes;

  /// Engine frame where the last note ends.
  final int end;
}

/// Turns [phrase] into flute-voice notes for a flute whose Sa is [saHz],
/// starting at engine frame [start]. This is where sargam becomes Hz
/// (CLAUDE.md rule 3).
ScheduledCall scheduleCall(
  Phrase phrase, {
  required double saHz,
  required int start,
  required int sampleRate,
  double matraSeconds = 1.0,
  Tuning tuning = Tuning.equal,
  double amplitude = 0.5,
}) {
  int frames(Fraction matras) => (matras.toDouble() * matraSeconds * sampleRate).round();
  double hzOf(Pitch p) => hzFromCents(tuning.centsOf(p), saHz);

  final sounding = phrase.sounding;
  final notes = <ScheduledNote>[];
  for (var i = 0; i < sounding.length; i++) {
    final n = sounding[i];
    final next = i + 1 < sounding.length ? sounding[i + 1] : null;
    notes.add(
      ScheduledNote(
        start: start + frames(n.start),
        duration: frames(n.end) - frames(n.start),
        hz: hzOf(n.pitch!),
        glideToHz: n.glideToNext && next != null ? hzOf(next.pitch!) : null,
        amplitude: amplitude,
      ),
    );
  }
  return ScheduledCall(notes, start + frames(phrase.length));
}

/// One metronome click, in engine frames.
class ScheduledClick {
  const ScheduledClick({required this.time, required this.beat, this.amplitude = 0.6});

  final int time;
  final Beat beat;
  final double amplitude;
}

/// Turns a round's [clicks] (docs/08 M3-B) into engine frames: the round's
/// first matra at engine frame [start], [matraSeconds] per matra. Clicks
/// fall on whole matras of the same clock as the call, so the two can't
/// drift apart.
List<ScheduledClick> scheduleClicks(
  List<Click> clicks, {
  required int start,
  required int sampleRate,
  required double matraSeconds,
  double volume = 0.6,
}) => [
  for (final c in clicks)
    ScheduledClick(
      time: start + (c.matra * matraSeconds * sampleRate).round(),
      beat: c.beat,
      amplitude: volume,
    ),
];
