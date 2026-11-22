import 'package:aaroha_core/aaroha_core.dart';
import 'package:test/test.dart';

void main() {
  group('Swar', () {
    test('ascii letters round-trip', () {
      for (final swar in Swar.values) {
        expect(Swar.fromAscii(swar.ascii), swar);
      }
      expect(Swar.fromAscii('m'), Swar.ma);
      expect(Swar.fromAscii('M'), Swar.tivraMa);
    });

    test('pitch notation marks octaves', () {
      expect(const Pitch(Swar.ni, -1).ascii, '.N');
      expect(const Pitch(Swar.sa).ascii, 'S');
      expect(const Pitch(Swar.pa, 1).ascii, "P'");
    });
  });

  group('Tuning', () {
    test('equal temperament is 100 cents per swar', () {
      expect(Tuning.equal.centsOf(const Pitch(Swar.ga)), 400);
      expect(Tuning.equal.centsOf(const Pitch(Swar.pa, -1)), -500);
      expect(Tuning.equal.centsOf(const Pitch(Swar.sa, 1)), 1200);
    });

    test('nearest finds swar, octave and deviation', () {
      final r = Tuning.equal.nearest(370);
      expect(r.pitch, const Pitch(Swar.ga));
      expect(r.deviation, closeTo(-30, 1e-9));

      final low = Tuning.equal.nearest(-510);
      expect(low.pitch, const Pitch(Swar.pa, -1));
      expect(low.deviation, closeTo(-10, 1e-9));

      final high = Tuning.equal.nearest(1190);
      expect(high.pitch, const Pitch(Swar.sa, 1));
    });

    test('cents and hz convert both ways', () {
      expect(centsFromSa(440 * 1.5, 440), closeTo(701.955, 1e-3));
      expect(hzFromCents(1200, 392), closeTo(784, 1e-9));
    });
  });

  group('FluteKey', () {
    test('owner flutes use the assumed medium octaves', () {
      final hz = {for (final f in ownerFlutes) f.name: f.nominalSaHz};
      expect(hz['G medium'], closeTo(392.00, 0.01));
      expect(hz['A medium'], closeTo(440.00, 0.01));
      expect(hz['B medium'], closeTo(493.88, 0.01));
      expect(hz['C medium'], closeTo(523.25, 0.01));
      expect(hz['D# medium'], closeTo(622.25, 0.01));
    });

    test('bass is an octave below medium', () {
      const bass = FluteKey(PitchClass.e, FluteSize.bass);
      expect(bass.nominalSaHz, closeTo(329.63, 0.01));
    });
  });
}
