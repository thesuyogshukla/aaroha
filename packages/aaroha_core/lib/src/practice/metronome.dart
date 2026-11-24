import '../model/taal.dart';

/// One metronome click, [matra] matras after the round's first click.
class Click {
  const Click(this.matra, this.beat, {this.countIn = false, this.position = 0});

  final int matra;
  final Beat beat;

  /// Part of a count-in, not of the call or the response.
  final bool countIn;

  /// Where in the taal's cycle the click falls: matras after sam (0 is sam).
  /// Always 0 without a taal. The beat strip lights this matra (docs/08 M3-B).
  final int position;

  @override
  bool operator ==(Object other) =>
      other is Click &&
      other.matra == matra &&
      other.beat == beat &&
      other.countIn == countIn &&
      other.position == position;

  @override
  int get hashCode => Object.hash(matra, beat, countIn, position);

  @override
  String toString() => '${countIn ? 'in:' : ''}$matra${beat.name[0]}';
}

/// Where a round's clicks fall and where its call and response start, all
/// in whole matras from the round's first click (docs/08 M3-B).
class RoundClicks {
  const RoundClicks({
    required this.clicks,
    required this.callAt,
    required this.responseAt,
    required this.countInMatras,
  });

  final List<Click> clicks;

  /// The matra the call starts on: its sam.
  final int callAt;

  /// With a count-in, the matra the player is counted in to (a sam). With a
  /// free start, where the call ends: the player may start anywhere after.
  final int responseAt;

  /// Matras of each count-in; 0 for a free start.
  final int countInMatras;
}

/// How many matras a count-in lasts: the taal's last vibhag, leading into
/// sam, but never fewer than 3; 4 without a taal.
int countInLength(Taal? taal) {
  if (taal == null) return 4;
  final last = taal.vibhags.last;
  return last < 3 ? 3 : last;
}

/// The clicks of one round (docs/08 M3-B).
///
/// With [countIn], a count-in leads into the call, which starts on sam, and
/// another leads from the end of the call into the response, which starts
/// on a new sam. With a free start there is no count-in: the response may
/// start anywhere once the call has ended, and the metronome's cycle carries
/// on from the call.
///
/// With [metronome] on, every matra of the call and of [responseMatras]
/// matras of response clicks, marked by [taal] (sam, tali, khali), or all
/// alike without one. Off, only the count-ins click.
RoundClicks roundClicks({
  required int callMatras,
  required int responseMatras,
  Taal? taal,
  bool metronome = false,
  bool countIn = false,
}) {
  final c = countIn ? countInLength(taal) : 0;
  Beat beat(int fromSam) =>
      taal == null ? (fromSam == 0 ? Beat.sam : Beat.plain) : taal.beatAt(fromSam);
  int position(int fromSam) => taal == null ? 0 : fromSam % taal.matras;
  // A count-in clicks the matras just before a sam, as the taal marks
  // them (the end of the previous avartan); without a taal, all alike.
  List<Click> countInTo(int sam) => [
    for (var k = c; k > 0; k--)
      Click(
        sam - k,
        taal == null ? Beat.plain : taal.beatAt(taal.matras - k),
        countIn: true,
        position: taal == null ? 0 : position(taal.matras - k),
      ),
  ];

  final callAt = c;
  final responseAt = callAt + callMatras + c;
  final clicks = <Click>[
    if (countIn) ...countInTo(callAt),
    if (metronome)
      for (var m = 0; m < callMatras; m++) Click(callAt + m, beat(m), position: position(m)),
    if (countIn) ...countInTo(responseAt),
    if (metronome)
      for (var m = 0; m < responseMatras; m++)
        // Counted in, the response starts its own cycle; free, the call's
        // cycle carries on.
        Click(
          responseAt + m,
          beat(countIn ? m : callMatras + m),
          position: position(countIn ? m : callMatras + m),
        ),
  ];
  return RoundClicks(clicks: clicks, callAt: callAt, responseAt: responseAt, countInMatras: c);
}

/// The clicks for listening again without replaying the call: a count-in
/// (with [countIn]) and, with [metronome], [responseMatras] matras of clicks.
/// The call is left out, so [RoundClicks.callAt] equals
/// [RoundClicks.responseAt].
RoundClicks retryClicks({
  required int responseMatras,
  Taal? taal,
  bool metronome = false,
  bool countIn = false,
}) {
  final c = countIn ? countInLength(taal) : 0;
  final full = roundClicks(
    callMatras: 0,
    responseMatras: responseMatras,
    taal: taal,
    metronome: metronome,
    countIn: countIn,
  );
  // roundClicks counts in twice around an empty call; keep the second.
  return RoundClicks(
    clicks: [
      for (final k in full.clicks)
        if (k.matra >= c) Click(k.matra - c, k.beat, countIn: k.countIn, position: k.position),
    ],
    callAt: c,
    responseAt: c,
    countInMatras: c,
  );
}
