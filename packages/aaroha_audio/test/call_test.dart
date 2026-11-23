import 'package:aaroha_audio/aaroha_audio.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clicks and call notes land on the same frames', () {
    const sr = 48000;
    const matraSeconds = 60 / 90;
    final plan = roundClicks(
      callMatras: 4,
      responseMatras: 4,
      taal: Taal.keherwa,
      metronome: true,
      countIn: true,
    );
    const origin = 1000000;
    final clicks = scheduleClicks(
      plan.clicks,
      start: origin,
      sampleRate: sr,
      matraSeconds: matraSeconds,
    );
    final call = scheduleCall(
      parsePhrase('S R G m'),
      saHz: 391.08,
      start: origin + (plan.callAt * matraSeconds * sr).round(),
      sampleRate: sr,
      matraSeconds: matraSeconds,
    );
    final callClicks = [
      for (var i = 0; i < clicks.length; i++)
        if (!plan.clicks[i].countIn && plan.clicks[i].matra < plan.callAt + 4) clicks[i].time,
    ];
    // Within one frame of rounding.
    for (var k = 0; k < 4; k++) {
      expect((call.notes[k].start - callClicks[k]).abs(), lessThanOrEqualTo(1));
    }
    expect(clicks.first.time, origin);
    expect(clicks.first.beat, Beat.khali, reason: 'keherwa count-in starts on the khali vibhag');
    expect(clicks.map((c) => c.amplitude).toSet(), {0.6});
  });

  test('hundreds of matras on: no drift, one matra apart', () {
    final plan = roundClicks(callMatras: 200, responseMatras: 0, metronome: true);
    final clicks = scheduleClicks(plan.clicks, start: 0, sampleRate: 48000, matraSeconds: 0.8);
    expect(clicks.last.time, (199 * 0.8 * 48000).round());
    for (var i = 1; i < clicks.length; i++) {
      expect(clicks[i].time - clicks[i - 1].time, closeTo(38400, 1));
    }
  });
}
