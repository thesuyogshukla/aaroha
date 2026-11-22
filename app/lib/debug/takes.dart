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
  other('other', 'Anything else: say what in the label');

  const Take(this.id, this.instructions, {this.played});

  /// File name without extension.
  final String id;

  /// Shown under the picker.
  final String instructions;

  /// Expected notes in ASCII notation (docs/03), when the take has a fixed
  /// sequence. Others are left for the owner to fill in.
  final String? played;
}
