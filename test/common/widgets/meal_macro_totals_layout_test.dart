import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/carbohydrate_totals_summary.dart';
import 'package:diabeatthis/common/widgets/macro_value_tile.dart';
import 'package:diabeatthis/common/widgets/meal_macro_summary.dart';
import 'package:diabeatthis/common/widgets/nutrition_value_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'wrapped macro labels keep matching heights and totals use the same tile style',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: MealMacroSummary(
                  netCarbs: 61.2,
                  protein: 27.4,
                  fat: 27.2,
                  fiber: 6.9,
                  calories: 600,
                ),
              ),
            ),
          ),
        ),
      );
      final macros = find.byType(MacroValueTile);
      final firstSize = tester.getSize(macros.first);
      for (var i = 1; i < 4; i++) {
        expect(tester.getSize(macros.at(i)), firstSize);
      }
      final totals = find.byType(CarbohydrateTotalsSummary);
      expect(
        find.descendant(of: totals, matching: find.text('62 g')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: totals, matching: find.text('36 g')),
        findsOneWidget,
      );
      final tiles = find.descendant(
        of: totals,
        matching: find.byType(NutritionValueTile),
      );
      expect(tiles, findsNWidgets(2));
      expect(tester.getSize(tiles.first), tester.getSize(tiles.last));
      expect(
        tester.getTopLeft(totals).dy,
        greaterThan(tester.getBottomLeft(macros.first).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
