import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

String marks(Taal t) => [for (var m = 0; m < t.matras; m++) t.beatAt(m).name[0]].join();

void main() {
  test('taals are marked sam, tali, khali', () {
    expect(marks(Taal.teentaal), 'sppptpppkppptppp');
    expect(marks(Taal.keherwa), 'spppkppp');
    expect(marks(Taal.dadra), 'sppkpp');
    expect(marks(Taal.rupak), 'kpptptp', reason: "rupak's sam is khali");
    expect(marks(Taal.jhaptaal), 'sptppkptpp');
    expect(marks(Taal.ektaal), 'spkptpkptptp');
    expect(Taal.teentaal.beatAt(16), Beat.sam, reason: 'the next avartan');
    expect(Taal.rupak.shape, '3+2+2');
  });

  test('count-ins lead into sam with the last vibhag, at least 3 matras', () {
    expect(countInLength(null), 4);
    expect(countInLength(Taal.teentaal), 4);
    expect(countInLength(Taal.keherwa), 4);
    expect(countInLength(Taal.dadra), 3);
    expect(countInLength(Taal.rupak), 3);
  });

  test('free start, no metronome: no clicks, as before', () {
    final r = roundClicks(callMatras: 4, responseMatras: 10);
    expect(r.clicks, isEmpty);
    expect(r.callAt, 0);
    expect(r.responseAt, 4);
    expect(r.countInMatras, 0);
  });

  test('count-in only: a count-in before the call and before the response', () {
    final r = roundClicks(callMatras: 3, responseMatras: 10, countIn: true);
    expect(r.callAt, 4);
    expect(r.responseAt, 4 + 3 + 4);
    expect(r.clicks.map((c) => c.matra), [0, 1, 2, 3, 7, 8, 9, 10]);
    expect(r.clicks.every((c) => c.countIn), isTrue);
  });

  test('metronome in keherwa with a count-in: each part starts on sam', () {
    final r = roundClicks(
      callMatras: 6,
      responseMatras: 8,
      taal: Taal.keherwa,
      metronome: true,
      countIn: true,
    );
    expect(r.callAt, 4);
    expect(r.responseAt, 14);
    // Count-in (the end of an avartan: khali vibhag), then the call from sam.
    expect(r.clicks.take(4).map((c) => c.beat), [Beat.khali, Beat.plain, Beat.plain, Beat.plain]);
    expect(r.clicks[4], const Click(4, Beat.sam));
    expect(
      r.clicks.where((c) => !c.countIn && c.matra < 10).map((c) => c.beat.name[0]).join(),
      'spppkp',
    );
    // The response is counted in to a new sam.
    expect(r.clicks.firstWhere((c) => c.matra == 14), const Click(14, Beat.sam));
    // One click per matra, never two on the same matra.
    final matras = r.clicks.map((c) => c.matra).toList();
    expect(matras.toSet().length, matras.length);
    expect(matras, [for (var m = 0; m < 22; m++) m]);
  });

  test('free start with the metronome: the call\'s cycle carries on', () {
    final r = roundClicks(callMatras: 3, responseMatras: 6, taal: Taal.dadra, metronome: true);
    expect(r.responseAt, 3);
    expect(r.clicks.map((c) => c.beat.name[0]).join(), 'sppkppspp');
  });

  test('without a taal the metronome marks only where each part starts', () {
    final r = roundClicks(callMatras: 3, responseMatras: 3, metronome: true, countIn: true);
    expect(
      r.clicks.map((c) => '${c.countIn ? 'i' : ''}${c.beat.name[0]}').join(' '),
      'ip ip ip ip s p p ip ip ip ip s p p',
    );
  });

  test('listening again: one count-in, then the response', () {
    final r = retryClicks(responseMatras: 4, taal: Taal.dadra, metronome: true, countIn: true);
    expect(r.responseAt, 3);
    expect(
      r.clicks.map((c) => '${c.countIn ? 'i' : ''}${c.beat.name[0]}').join(' '),
      'ik ip ip s p p k',
    );
    expect(r.clicks.map((c) => c.matra), [0, 1, 2, 3, 4, 5, 6]);
    expect(retryClicks(responseMatras: 4).clicks, isEmpty);
  });

  group('positions in the cycle, for the beat strip', () {
    const keherwa = Taal.keherwa;
    List<int> positions(RoundClicks r) => [for (final c in r.clicks) c.position];

    test('a free start carries the call\'s cycle into the turn', () {
      final r = roundClicks(callMatras: 6, responseMatras: 5, taal: keherwa, metronome: true);
      expect(positions(r), [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2]);
      expect(
        [for (final c in r.clicks) c.beat == Beat.sam],
        [
          true, false, false, false, false, false, false, false, true, false, false, //
        ],
      );
    });

    test('counted in, the count-in ends the cycle and the turn starts a new one', () {
      final r = roundClicks(
        callMatras: 6,
        responseMatras: 3,
        taal: keherwa,
        metronome: true,
        countIn: true,
      );
      expect(positions(r), [4, 5, 6, 7, 0, 1, 2, 3, 4, 5, 4, 5, 6, 7, 0, 1, 2]);
    });

    test('listening again keeps them', () {
      final r = retryClicks(responseMatras: 3, taal: keherwa, metronome: true, countIn: true);
      expect(positions(r), [4, 5, 6, 7, 0, 1, 2]);
    });

    test('without a taal every click is at 0', () {
      final r = roundClicks(callMatras: 3, responseMatras: 2, metronome: true, countIn: true);
      expect(positions(r).toSet(), {0});
    });
  });

  test('the turn may start on any sam after the call, or on the one counted to', () {
    List<int> matras(RoundClicks r) => [for (final i in r.turnSams) r.clicks[i].matra];
    // Free start: a 4-matra call in keherwa ends mid-cycle; the next sam is
    // 4 matras later, then every 8.
    final free = roundClicks(
      callMatras: 4,
      responseMatras: 20,
      taal: Taal.keherwa,
      metronome: true,
    );
    expect(matras(free), [8, 16]);
    // Counted in: the turn's own sam, then every cycle.
    final counted = roundClicks(
      callMatras: 8,
      responseMatras: 16,
      taal: Taal.keherwa,
      metronome: true,
      countIn: true,
    );
    expect(matras(counted), [counted.responseAt, counted.responseAt + 8]);
    // Listening again: sams from the first response click.
    final again = retryClicks(responseMatras: 12, taal: Taal.dadra, metronome: true);
    expect(matras(again), [0, 6]);
    // Count-in clicks are never a start, even on sam's position.
    expect(
      roundClicks(callMatras: 6, responseMatras: 0, taal: Taal.dadra, countIn: true).turnSams,
      isEmpty,
    );
  });

  test('a free start waits for the next sam after the call', () {
    expect(matrasToNextSam(4, Taal.teentaal), 12);
    expect(matrasToNextSam(8, Taal.keherwa), 0);
    expect(matrasToNextSam(5, Taal.rupak), 2);
    expect(matrasToNextSam(6, null), 0);
    // It agrees with where the turn's first sam is clicked.
    final r = roundClicks(callMatras: 4, responseMatras: 16, taal: Taal.teentaal, metronome: true);
    expect(r.clicks[r.turnSams.first].matra - r.responseAt, matrasToNextSam(4, Taal.teentaal));
  });
}
