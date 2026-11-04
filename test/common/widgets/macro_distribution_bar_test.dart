import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/macro_distribution_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'macro segments fill the bar height and divide its width in gram proportions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: MacroDistributionBar(
                  carbs: 50,
                  protein: 30,
                  fat: 20,
                  basisLabel: 'Per portion',
                ),
              ),
            ),
          ),
        ),
      );
      final segments = find.descendant(
        of: find.byType(MacroDistributionBar),
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsNWidgets(3));
      final sizes = List.generate(
        3,
        (index) => tester.getSize(segments.at(index)),
      );
      expect(sizes.map((size) => size.height), everyElement(14));
      expect(sizes[0].width, closeTo(200, .01));
      expect(sizes[1].width, closeTo(120, .01));
      expect(sizes[2].width, closeTo(80, .01));
    },
  );
}
