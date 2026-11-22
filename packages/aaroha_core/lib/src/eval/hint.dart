import '../model/tuning.dart';
import 'judge.dart';

/// Which way a played note was off.
enum HintDirection { low, high }

/// How far off, without naming any swar (docs/05 "Hints").
enum HintSize {
  /// The right swar, out of tune.
  little,

  /// A different swar up to a whole tone away.
  too,

  /// A different swar further away.
  much,

  /// The right swar in another octave.
  octave,
}

/// A hint for one judged note: never names a swar, so the ear keeps searching.
sealed class NoteHint {
  const NoteHint();
}

class HintRight extends NoteHint {
  const HintRight();
}

class HintOff extends NoteHint {
  const HintOff(this.direction, this.size);
  final HintDirection direction;
  final HintSize size;
}

class HintMissing extends NoteHint {
  const HintMissing();
}

class HintExtra extends NoteHint {
  const HintExtra();
}

/// Up to this far from the target (in cents), a wrong swar is "too" low or
/// high; beyond it, "much too".
const _tooCents = 250.0;

NoteHint hintFor(JudgedNote note, Tuning tuning) {
  switch (note.verdict) {
    case Verdict.pass:
      return const HintRight();
    case Verdict.missing:
      return const HintMissing();
    case Verdict.extra:
      return const HintExtra();
    case Verdict.outOfTune:
    case Verdict.wrongSwar:
    case Verdict.wrongOctave:
      final diff = note.played!.cents - tuning.centsOf(note.target!);
      final direction = diff < 0 ? HintDirection.low : HintDirection.high;
      final size = switch (note.verdict) {
        Verdict.outOfTune => HintSize.little,
        Verdict.wrongOctave => HintSize.octave,
        _ => diff.abs() <= _tooCents ? HintSize.too : HintSize.much,
      };
      return HintOff(direction, size);
  }
}

/// Plain-language text for a hint.
String hintText(NoteHint hint) => switch (hint) {
  HintRight() => 'Right',
  HintMissing() => 'A note is missing',
  HintExtra() => 'One note too many',
  HintOff(:final direction, :final size) => switch (size) {
    HintSize.little => 'Right note, a little ${direction == HintDirection.low ? 'flat' : 'sharp'}',
    HintSize.too => 'Too ${direction.name}',
    HintSize.much => 'Much too ${direction.name}',
    HintSize.octave => 'Right note, an octave too ${direction.name}',
  },
};

/// One symbol per note position for phrases: ✓ ↑ ↓ (↑ means play higher).
String hintArrow(NoteHint hint) => switch (hint) {
  HintRight() => '✓',
  HintMissing() => '·',
  HintExtra() => '+',
  HintOff(:final direction) => direction == HintDirection.low ? '↑' : '↓',
};
