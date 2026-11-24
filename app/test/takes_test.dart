import 'package:aaroha/debug/takes.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rhythm takes are whole avartans of keherwa', () {
    final rhythm = Take.values.where((t) => t.rhythm != null).toList();
    expect(rhythm, hasLength(5));
    for (final t in rhythm) {
      final result = parseNotation('taal: keherwa\n---\n${t.rhythm}');
      expect(result.errors, isEmpty, reason: t.id);
      expect(result.phrase!.length.numerator % 8, 0, reason: t.id);
      expect(t.notes, isNotNull);
    }
    expect(Take.rhythmSteps.notes, "S R G m P D N S' S' N D P m G R S");
    expect(Take.rhythmRepeatsFast.notes!.split(' '), hasLength(13));
    expect(Take.rhythmRepeats.countRepeats, isTrue);
    expect(Take.rhythmHolds.countRepeats, isFalse);
    expect(Take.saHold.notes, 'S');
  });
}
