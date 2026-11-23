import 'package:aaroha/practice/practice_settings.dart';
import 'package:aaroha/widgets/sargam.dart';
import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a phrase of one-matra notes draws as before', (tester) async {
    await tester.pumpWidget(_wrap(PhraseSargam(parsePhrase('S R G m'))));
    expect(find.byType(SargamRow), findsOneWidget);
    expect(find.byType(SwarGlyph), findsNWidgets(4));
  });

  testWidgets('holds, rests, bars and shared matras are drawn', (tester) async {
    await tester.pumpWidget(_wrap(PhraseSargam(parsePhrase('S - RG m | P _ DP mG ||'))));
    expect(find.byType(SargamRow), findsNothing);
    expect(find.byType(SwarGlyph), findsNWidgets(9));
    expect(find.text('-'), findsOneWidget, reason: 'the hold');
    expect(find.text('_'), findsOneWidget, reason: 'the rest');
    expect(find.text('|'), findsOneWidget);
    expect(find.text('||'), findsOneWidget);
    // One arc for each of the three shared matras.
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_MatraArc',
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('in Devanagari a hold is an avagraha', (tester) async {
    await tester.pumpWidget(_wrap(PhraseSargam(parsePhrase('S - R'), script: Script.devanagari)));
    expect(find.text('ऽ'), findsOneWidget);
    expect(find.text('सा'), findsOneWidget);
  });

  testWidgets('a hold takes its note\'s verdict colour', (tester) async {
    const red = Color(0xFFFF0000), green = Color(0xFF00FF00);
    await tester.pumpWidget(_wrap(PhraseSargam(parsePhrase('S - R'), colors: const [red, green])));
    expect(tester.widget<Text>(find.text('-')).style!.color, red);
  });
}
