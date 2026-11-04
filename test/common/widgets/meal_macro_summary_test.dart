import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/nutrition/macro_colors.dart';
import 'package:diabeatthis/common/widgets/macro_distribution_bar.dart';
import 'package:diabeatthis/common/widgets/macro_value_tile.dart';
import 'package:diabeatthis/common/widgets/meal_macro_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'shared meal macros fit a narrow card at text scale $scale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const SingleChildScrollView(
                  child: SizedBox(
                    width: 280,
                    child: MealMacroSummary(
                      netCarbs: 56.4,
                      protein: 80.4,
                      fat: 23.3,
                      fiber: 12.9,
                      calories: 757,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final tiles = find.byType(MacroValueTile);
        expect(tiles, findsNWidgets(4));
        expect(find.text('56,4 g'), findsOneWidget);
        expect(find.text('Błonnik'), findsOneWidget);
        expect(
          tester
              .widgetList<MacroValueTile>(tiles)
              .map((tile) => tile.accentColor),
          [
            MacroColors.carbs,
            MacroColors.protein,
            MacroColors.fat,
            MacroColors.fiber,
          ],
        );
        final bar = tester.widget<MacroDistributionBar>(
          find.byType(MacroDistributionBar),
        );
        expect(bar.carbs, 56.4);
        expect(bar.fiber, 12.9);
        if (scale == 1) {
          final top = tester.getTopLeft(tiles.first).dy;
          for (var i = 1; i < 4; i++) {
            expect(tester.getTopLeft(tiles.at(i)).dy, top);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
