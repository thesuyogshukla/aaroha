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
    this.start = 0,
  });

  final List<Click> clicks;

  /// The matra the call starts on: its sam.
  final int callAt;

  /// With a count-in, the matra the player is counted in to (a sam). With a
  /// free start, where the call ends: the player may start anywhere after.
  final int responseAt;

  /// Matras of each count-in; 0 for a free start.
  final int countInMatras;

  /// Where in the taal's cycle the phrase starts: matras after sam (D57).
  /// 0 for a phrase that starts on sam, as every phrase did before tunes.
  final int start;

  /// Indexes into [clicks] of the matras the player's turn may start on
  /// (docs/05 §5): every click at the phrase's place in the cycle ([start];
  /// sam for most phrases) from [responseAt] on, count-ins left out. Counted
  /// in, the first is the one counted to; free, any after the call. Rhythm
  /// judging times the phrase from whichever fits.
  List<int> get turnStarts => [
    for (var i = 0; i < clicks.length; i++)
      if (clicks[i].position == start && !clicks[i].countIn && clicks[i].matra >= responseAt) i,
  ];
}

/// How many matras a count-in lasts: the taal's last vibhag, leading into
/// sam, but never fewer than 3; 4 without a taal.
int countInLength(Taal? taal) {
  if (taal == null) return 4;
  final last = taal.vibhags.last;
  return last < 3 ? 3 : last;
}

/// With a free start and a taal, how many matras after the call the
/// phrase's place in the cycle comes round again (sam for most phrases; D54,
/// D57): the player is told to start there, so the listening window waits
/// that long too. 0 when the call is whole avartans.
int matrasToNextSam(int callMatras, Taal? taal) =>
    taal == null ? 0 : (taal.matras - callMatras % taal.matras) % taal.matras;

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
///
/// [start] is where in the taal's cycle the phrase begins, in matras after
/// sam (D57): a line of a tune may come in on khali. The call then starts on
/// that matra, a count-in leads into it, and the turn starts there again.
RoundClicks roundClicks({
  required int callMatras,
  required int responseMatras,
  Taal? taal,
  bool metronome = false,
  bool countIn = false,
  int start = 0,
}) {
  final c = countIn ? countInLength(taal) : 0;
  final s = taal == null ? 0 : start % taal.matras;
  // Where a matra falls in the cycle, counted from sam (Dart's % keeps it
  // in 0..matras-1, so matras before sam wrap to the end of the avartan).
  int position(int fromSam) => taal == null ? 0 : fromSam % taal.matras;
  Click at(int matra, int fromSam, {bool countIn = false}) => Click(
    matra,
    taal != null
        ? taal.beatAt(position(fromSam))
        : (!countIn && fromSam == 0 ? Beat.sam : Beat.plain),
    countIn: countIn,
    position: position(fromSam),
  );
  // A count-in clicks the matras just before the phrase's first one, as the
  // taal marks them (for a phrase on sam, the end of the previous avartan);
  // without a taal, all alike.
  List<Click> countInTo(int matra) => [
    for (var k = c; k > 0; k--) at(matra - k, s - k, countIn: true),
  ];

  final callAt = c;
  final responseAt = callAt + callMatras + c;
  final clicks = <Click>[
    if (countIn) ...countInTo(callAt),
    if (metronome)
      for (var m = 0; m < callMatras; m++) at(callAt + m, s + m),
    if (countIn) ...countInTo(responseAt),
    if (metronome)
      for (var m = 0; m < responseMatras; m++)
        // Counted in, the response starts at the phrase's place again;
        // free, the call's cycle carries on.
        at(responseAt + m, countIn ? s + m : s + callMatras + m),
  ];
  return RoundClicks(
    clicks: clicks,
    callAt: callAt,
    responseAt: responseAt,
    countInMatras: c,
    start: s,
  );
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
  int start = 0,
}) {
  final c = countIn ? countInLength(taal) : 0;
  final full = roundClicks(
    callMatras: 0,
    responseMatras: responseMatras,
    taal: taal,
    metronome: metronome,
    countIn: countIn,
    start: start,
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
    start: full.start,
  );
}
