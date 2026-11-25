import 'dart:math' as math;

import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

const sa = 392.0;
const hop = 480;
const frameMs = 10;

/// Builds frames at 100 per second from (cents, ms) segments. A null cents
/// value is silence.
class FrameBuilder {
  final frames = <PitchFrame>[];
  var _time = 0;

  void note(double? cents, int ms, {double? rms, double? confidence}) {
    for (var i = 0; i < ms ~/ frameMs; i++) {
      frames.add(
        PitchFrame(
          time: _time,
          hz: cents == null ? 0 : hzFromCents(cents, sa),
          confidence: confidence ?? (cents == null ? 0.2 : 0.97),
          rms: rms ?? (cents == null ? 0.0001 : 0.1),
        ),
      );
      _time += hop;
    }
  }

  void skip(int ms) => _time += ms * hop ~/ frameMs;
}

List<String> asciiOf(List<DetectedNote> notes) => [for (final n in notes) n.pitch.ascii];

void main() {
  test('a held note becomes one note with its deviation', () {
    final b = FrameBuilder()..note(370, 600);
    final notes = segmentNotes(b.frames, saHz: sa);
    expect(asciiOf(notes), ['G']);
    expect(notes.single.deviation, closeTo(-30, 0.01));
    expect(notes.single.durationMs(48000), closeTo(600, 1));
  });

  test('a sequence with silences between notes', () {
    final b = FrameBuilder()
      ..note(0, 400)
      ..note(null, 100)
      ..note(200, 400)
      ..note(null, 100)
      ..note(-500, 400);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S', 'R', '.P']);
  });

  test('short transitions between notes are dropped', () {
    final b = FrameBuilder()
      ..note(0, 300)
      ..note(100, 50) // slide through komal Re
      ..note(200, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S', 'R']);
  });

  test('a blip inside a held note does not split it', () {
    final b = FrameBuilder()
      ..note(400, 300)
      ..note(500, 40)
      ..note(400, 300);
    final notes = segmentNotes(b.frames, saHz: sa);
    expect(asciiOf(notes), ['G']);
  });

  test('repeated notes split on silence', () {
    final b = FrameBuilder()
      ..note(0, 300)
      ..note(null, 60)
      ..note(0, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S', 'S']);
  });

  test('a dropout shorter than 40 ms does not split a note', () {
    final b = FrameBuilder()
      ..note(0, 300)
      ..note(null, 20)
      ..note(0, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S']);
  });

  test('a loud unvoiced stretch (drone pluck) does not split a note', () {
    final b = FrameBuilder()
      ..note(0, 300)
      ..note(null, 100, rms: 0.1)
      ..note(0, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S']);
  });

  test('a long loud unvoiced stretch does split', () {
    final b = FrameBuilder()
      ..note(0, 300)
      ..note(null, 200, rms: 0.1)
      ..note(0, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S', 'S']);
  });

  test('repeated notes split on a loudness dip', () {
    final b = FrameBuilder()
      ..note(0, 300)
      ..note(0, 50, rms: 0.01)
      ..note(0, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S', 'S']);
  });

  test('breath pulsing (~12 dB swings) does not split a note', () {
    // Shape taken from a real S' take: peaks around -13 dB, troughs around
    // -25 dB, about 2.5 swings per second.
    final b = FrameBuilder();
    for (var i = 0; i < 200; i++) {
      final db = -19 - 6 * math.cos(2 * math.pi * 2.5 * i / 100);
      b.note(1180, 10, rms: math.pow(10, db / 20).toDouble());
    }
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ["S'"]);
  });

  test('a fade into silence stays one note', () {
    final b = FrameBuilder();
    for (var i = 0; i < 150; i++) {
      b.note(700, 10, rms: 0.1 * math.pow(10, -30 * i / 150 / 20).toDouble());
    }
    b.note(null, 200);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['P']);
  });

  test('a deep dip that never recovers is the note\'s tail', () {
    final b = FrameBuilder()
      ..note(0, 400)
      ..note(0, 200, rms: 0.01)
      ..note(null, 200);
    final notes = segmentNotes(b.frames, saHz: sa);
    expect(asciiOf(notes), ['S']);
    expect(notes.single.durationMs(48000), closeTo(600, 10));
  });

  test('a tongued repeat at -18 dB still splits', () {
    final b = FrameBuilder()
      ..note(400, 300)
      ..note(400, 30, rms: 0.0125)
      ..note(400, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['G', 'G']);
  });

  test('a short wobbly stretch is a transition, not a note', () {
    // Real take: pitch flickering between Sa and +125 c for ~150 ms.
    final b = FrameBuilder()..note(0, 400);
    for (var i = 0; i < 15; i++) {
      b.note(i.isEven ? 125 : 70, 10);
    }
    b.note(0, 400);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S']);
  });

  test('a short steady note between two others is kept', () {
    final b = FrameBuilder()
      ..note(0, 300)
      ..note(100, 180)
      ..note(0, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S', 'r', 'S']);
  });

  test('a short octave flip at a note\'s start is part of the note', () {
    // Real take: Pa's attack cracked and read as mandra Pa for 150 ms.
    final b = FrameBuilder()
      ..note(-510, 150)
      ..note(690, 500);
    final notes = segmentNotes(b.frames, saHz: sa);
    expect(asciiOf(notes), ['P']);
    expect(notes.single.durationMs(48000), closeTo(650, 10));
    expect(notes.single.deviation, closeTo(-10, 0.5));
  });

  test('a short octave flip at a note\'s end is part of the note', () {
    final b = FrameBuilder()
      ..note(1100, 500)
      ..note(-100, 150);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['N']);
  });

  group('a softer note after a dip (D51)', () {
    test('is a note, not the last one\'s tail', () {
      // Session 43: G peaking at -25 dB, a short dip, then a clean D at
      // -31 dB: it never got back within 6 dB of G and vanished.
      final b = FrameBuilder()
        ..note(386, 560, rms: 0.05)
        ..note(386, 40, rms: 0.004)
        ..note(884, 340, rms: 0.022)
        ..note(386, 600, rms: 0.05);
      expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['G', 'D', 'G']);
    });

    test('the same swar coming back softer is still the tail', () {
      final b = FrameBuilder()
        ..note(386, 560, rms: 0.05)
        ..note(386, 40, rms: 0.004)
        ..note(386, 200, rms: 0.022);
      expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['G']);
    });
  });

  group('a cracked attack (D48)', () {
    test('Pa cracking up a fifth is Pa, with the crack noted', () {
      // Session 33: P tongued hard sounds near taar Re (third mode of the
      // all-closed fingering) for 210 ms, then settles.
      final b = FrameBuilder()
        ..note(1387, 210)
        ..note(-512, 30)
        ..note(700, 600);
      final notes = segmentNotes(b.frames, saHz: sa);
      expect(asciiOf(notes), ['P']);
      expect(notes.single.crack?.ascii, "R'");
      expect(notes.single.durationMs(48000), closeTo(840, 10), reason: 'onset at the crack');
      expect(notes.single.deviation, closeTo(0, 0.5), reason: 'pitch from the settled note');
    });

    test('through more than one mode', () {
      // Session 34: mandra Pa for 120 ms, near taar Re for 180 ms, then Pa.
      final b = FrameBuilder()
        ..note(-510, 120)
        ..note(1390, 180)
        ..note(-512, 30)
        ..note(711, 600);
      final notes = segmentNotes(b.frames, saHz: sa);
      expect(asciiOf(notes), ['P']);
      expect(notes.single.crack?.ascii, "R'");
    });

    test('after a note, moving on legato', () {
      final b = FrameBuilder()
        ..note(386, 600)
        ..note(1395, 200)
        ..note(700, 600);
      final notes = segmentNotes(b.frames, saHz: sa);
      expect(asciiOf(notes), ['G', 'P']);
      expect([for (final n in notes) n.crack?.ascii], [null, "R'"]);
    });

    test('a clean attack has no crack', () {
      final b = FrameBuilder()..note(700, 600);
      expect(segmentNotes(b.frames, saHz: sa).single.crack, isNull);
    });

    test('a fifth held longer is a played note', () {
      final b = FrameBuilder()
        ..note(1404, 300)
        ..note(702, 600);
      expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ["R'", 'P']);
    });

    test('a re-tongued note a fifth above is a played note', () {
      // A loudness dip between them: the player articulated P.
      final b = FrameBuilder()
        ..note(1404, 200)
        ..note(1404, 40, rms: 0.005)
        ..note(702, 600);
      expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ["R'", 'P']);
    });

    test('a short note at another interval is a played note', () {
      final b = FrameBuilder()
        ..note(1200, 200)
        ..note(702, 600);
      expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ["S'", 'P']);
    });
  });

  test('a long overblow is still its own note', () {
    // Real take: Ga overblown into taar Ga for 320 ms.
    final b = FrameBuilder()
      ..note(370, 500)
      ..note(1550, 320)
      ..note(370, 500);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['G', "G'", 'G']);
  });

  test('a faint, unclear note is a breath, not a note', () {
    // Real session: a barely sounded Pa between Ni and Ga, ~19 dB quieter
    // with confidence 0.87, was read as mandra Pa.
    final b = FrameBuilder()
      ..note(1100, 600)
      ..note(null, 60)
      ..note(-500, 290, rms: 0.012, confidence: 0.87)
      ..note(null, 60)
      ..note(400, 600);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['N', 'G']);
  });

  test('a note below the flute\'s range is dropped', () {
    // Session 28: after G, the drone's low string carried on ~22 dB down and
    // the tracker reported it at its search floor (-700 c), as mandra Ma.
    final b = FrameBuilder()
      ..note(1200, 600)
      ..note(400, 600)
      ..note(null, 200)
      ..note(-672, 200, rms: 0.006, confidence: 0.92);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ["S'", 'G', '.m'], reason: 'no floor');
    const floor = SegmenterConfig(floorCents: -600); // a semitone below mandra Pa
    expect(asciiOf(segmentNotes(b.frames, saHz: sa, config: floor)), ["S'", 'G']);
    final low = FrameBuilder()..note(-500, 600);
    expect(asciiOf(segmentNotes(low.frames, saHz: sa, config: floor)), [
      '.P',
    ], reason: 'mandra Pa stays');
  });

  test('a faint but clear note stays', () {
    final b = FrameBuilder()
      ..note(1100, 600)
      ..note(null, 60)
      ..note(700, 400, rms: 0.012) // ~19 dB quieter, confidence 0.97
      ..note(null, 60)
      ..note(400, 600);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['N', 'P', 'G']);
  });

  test('a softer but real note stays', () {
    final b = FrameBuilder()
      ..note(1100, 600)
      ..note(null, 60)
      ..note(700, 400, rms: 0.03) // about 10 dB quieter
      ..note(null, 60)
      ..note(400, 600);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['N', 'P', 'G']);
  });

  test('a single quiet note is never compared with itself', () {
    final b = FrameBuilder()..note(0, 600, rms: 0.002);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['S']);
  });

  test('a capture gap splits notes', () {
    final b = FrameBuilder()..note(700, 300);
    b.skip(200);
    b.note(700, 300);
    expect(asciiOf(segmentNotes(b.frames, saHz: sa)), ['P', 'P']);
  });

  test('single-frame octave errors are repaired', () {
    final b = FrameBuilder()..note(400, 200);
    b.note(1600, 10); // tracker jumped an octave for one frame
    b.note(400, 200);
    final notes = segmentNotes(b.frames, saHz: sa);
    expect(asciiOf(notes), ['G']);
  });

  test('hysteresis keeps a note near a boundary from flickering', () {
    final b = FrameBuilder()..note(400, 200);
    for (var i = 0; i < 10; i++) {
      b
        ..note(445, 20)
        ..note(455, 20);
    }
    final notes = segmentNotes(b.frames, saHz: sa);
    expect(asciiOf(notes), ['G']);
  });

  test('stable cents skip the attack', () {
    final b = FrameBuilder()
      ..note(330, 70) // breathy, flat attack
      ..note(400, 500);
    final notes = segmentNotes(b.frames, saHz: sa);
    expect(asciiOf(notes), ['G']);
    expect(notes.single.deviation, closeTo(0, 0.01));
  });

  test('quiet frames below the noise floor are ignored', () {
    final b = FrameBuilder()..note(0, 400, rms: 0.002);
    final notes = segmentNotes(
      b.frames,
      saHz: sa,
      config: const SegmenterConfig(noiseFloor: 0.001),
    );
    expect(notes, isEmpty);
  });
}
