import 'package:aaroha_core/aaroha_core.dart';

/// Fixture takes from docs/07-test-fixtures.md. A recording is saved as
/// `recordings/<flute>/<take>.wav` with a `<take>.yaml` label beside it.
enum Take {
  silence('silence', '5 s of nothing (noise floor)'),
  saHold('sa-hold', 'Sa, held 5 s', played: 'S'),
  droneOnly('drone-only', 'Drone on, play nothing for 5 s'),
  withDrone(
    'with-drone',
    'Drone on: slow S R G m P D N S\', ~2 s each',
    played: "S R G m P D N S'",
  ),
  scaleSlow(
    'scale-slow',
    'Every swar .P to P\', ~2 s each, breath between',
    played: ".P .d .D .n .N S r R g G m M P d D n N S' r' R' g' G' m' M' P'",
  ),
  taarHolds('taar-holds', 'S\' R\' G\' m\' P\', ~3 s each', played: "S' R' G' m' P'"),
  deviations(
    'deviations',
    'Ga in tune, flat, sharp; then Ni, then Re',
    played: 'G G G N N N R R R',
  ),
  repeats(
    'repeats',
    'S S S S tongued, S S S S breath, G G G G tongued',
    played: 'S S S S S S S S G G G G',
  ),
  phrases(
    'phrases',
    'The 5 phrases in fixtures/phrases.txt, a pause between phrases',
    played: "S R G m P , P m G R S , S G R m G P , .N R G R S , S' N D P m G R S",
  ),
  ornaments('ornaments', 'A few meends and kans'),

  // Rhythm takes (docs/08 M3-D): played to the metronome after a count-in,
  // in keherwa, at the tempo picked. The label records where every matra
  // fell, so onsets can be checked.
  rhythmSteps(
    'rhythm-steps',
    'One swar on each click, up and down',
    rhythm: "S R G m | P D N S' || S' N D P | m G R S ||",
  ),
  rhythmHolds(
    'rhythm-holds',
    'Long and short notes: hold through the dashes',
    rhythm: 'S - R G | m - - - || P - m G | R - S - ||',
  ),
  rhythmHalves(
    'rhythm-halves',
    'Two swars to a click where they share a matra',
    rhythm: 'SR GR S - | RG mG R - || Gm Pm G - | RG RS S - ||',
  ),
  rhythmRepeats(
    'rhythm-repeats',
    'Repeated swars, each one tongued, one on each click',
    rhythm: 'S S S S | R R R R || G G G G | S - - - ||',
  ),
  rhythmRepeatsFast(
    'rhythm-repeats-fast',
    'Repeated swars, two to a click, each tongued',
    rhythm: 'SS SS RR RR | GG GG S - ||',
  ),
  other('other', 'Anything else: say what in the label');

  const Take(this.id, this.instructions, {this.played, this.rhythm});

  /// File name without extension.
  final String id;

  /// Shown under the picker.
  final String instructions;

  /// Expected notes in ASCII notation (docs/03), when the take has a fixed
  /// sequence. Others are left for the owner to fill in.
  final String? played;

  /// For a rhythm take: the phrase with its durations (docs/03), played to
  /// the metronome from sam.
  final String? rhythm;

  /// The swars of the take in order: [played], or the [rhythm]'s pitches.
  String? get notes =>
      played ??
      (rhythm == null ? null : parsePhrase(rhythm!).pitches.map((p) => p.ascii).join(' '));

  /// Repeated swars must each count as a note.
  bool get countRepeats => this == repeats || this == rhythmRepeats || this == rhythmRepeatsFast;
}
