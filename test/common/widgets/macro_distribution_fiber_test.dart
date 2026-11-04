import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/macro_distribution_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fiber has a brown segment and participates in the gram total', (
    tester,
  ) async {
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
                carbs: 20,
                protein: 10,
                fat: 5,
                fiber: 5,
                basisLabel: 'Per portion',
                showLegend: false,
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
    expect(segments, findsNWidgets(4));
    expect(tester.getSize(segments.at(0)).width, closeTo(200, .01));
    expect(tester.getSize(segments.at(1)).width, closeTo(100, .01));
    expect(tester.getSize(segments.at(2)).width, closeTo(50, .01));
    expect(tester.getSize(segments.at(3)).width, closeTo(50, .01));
    expect(
      tester.widget<ColoredBox>(segments.at(3)).color,
      Colors.brown.shade400,
    );
  });
}
