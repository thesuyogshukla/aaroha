import 'dart:math' as math;

import '../eval/pitch_frame.dart';

/// How long practice listens for one attempt (docs/04, Session controller).
///
/// The player gets [waitSecondsFor] from [from] to start: a count-in, if
/// any, then twice the phrase's length plus 4 s, at least 8 s. Once they start, they always get
/// twice the phrase's length plus 1.5 s from their first note, so a late
/// start isn't cut off. The attempt usually ends sooner, when the player
/// stops; this is only the limit.
class ListenWindow {
  ListenWindow({
    required int from,
    required this.phraseSeconds,
    required this.sampleRate,
    this.leadSeconds = 0,
    this.minHz = 0,
  }) : _from = from,
       _deadline = from + _frames(leadSeconds + waitSecondsFor(phraseSeconds), sampleRate);

  /// How long the target takes at the call's tempo.
  final double phraseSeconds;
  final int sampleRate;

  /// A count-in before the player's turn.
  final double leadSeconds;

  /// Pitches below this aren't a start: below the flute's range, they are
  /// the drone read at the tracker's floor (decisions.md D37).
  final double minHz;

  int _from;
  int _deadline;
  int? _started;

  /// Engine frame the window opens at.
  int get from => _from;

  /// Engine frame the window closes at, by now.
  int get deadline => _deadline;

  /// Where the player's first note began, once heard.
  int? get started => _started;

  /// The latest the window can close: a first note heard just before the
  /// first deadline. Clicks are scheduled this far.
  int get latestDeadline =>
      _from +
      _frames(
        leadSeconds + waitSecondsFor(phraseSeconds) + playSecondsFor(phraseSeconds),
        sampleRate,
      );

  /// Waiting for the player to start: never under 8 s, the old fixed limit
  /// for listening again.
  static double waitSecondsFor(double phraseSeconds) => math.max(8, phraseSeconds * 2 + 4);

  /// From the player's first note.
  static double playSecondsFor(double phraseSeconds) => phraseSeconds * 2 + 1.5;

  /// Frames below this confidence aren't a start (as the segmenter).
  static const startConfidence = 0.85;

  /// Moves the whole window, e.g. once the call's echo is measured.
  void shift(int frames) {
    _from += frames;
    _deadline += frames;
  }

  /// Takes in newly heard frames. The first confident pitch inside the
  /// window is the player's start, and the deadline moves out to give them
  /// the whole phrase from there.
  void heard(Iterable<PitchFrame> frames) {
    if (_started != null) return;
    for (final f in frames) {
      if (f.time < _from || f.hz <= minHz || f.confidence < startConfidence) continue;
      _started = f.time;
      _deadline = math.max(_deadline, f.time + _frames(playSecondsFor(phraseSeconds), sampleRate));
      return;
    }
  }

  static int _frames(double seconds, int sampleRate) => (seconds * sampleRate).round();
}
