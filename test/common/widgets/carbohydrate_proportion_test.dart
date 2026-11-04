import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/nutrition/macro_colors.dart';
import 'package:diabeatthis/common/widgets/carbohydrate_totals_summary.dart';
import 'package:diabeatthis/common/widgets/nutrition_value_tile.dart';
import 'package:diabeatthis/common/widgets/proportion_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'carbs and eCarbs share tile and segment colors and show the rounded-total ratio',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: CarbohydrateTotalsSummary(
                netCarbs: 61.2,
                protein: 27.4,
                fat: 27.2,
              ),
            ),
          ),
        ),
      );
      final tiles = tester
          .widgetList<NutritionValueTile>(find.byType(NutritionValueTile))
          .toList();
      expect(tiles[0].accentColor, MacroColors.carbs);
      expect(tiles[1].accentColor, MacroColors.fat);
      final bar = tester.widget<ProportionBar>(find.byType(ProportionBar));
      expect(bar.values, [62, 36]);
      expect(bar.colors, [MacroColors.carbs, MacroColors.fat]);
      expect(find.text('63%'), findsOneWidget);
      expect(find.text('37%'), findsOneWidget);
      final segments = find.descendant(
        of: find.byType(ProportionBar),
        matching: find.byType(ColoredBox),
      );
      expect(
        tester.getSize(segments.first).width /
            tester.getSize(segments.last).width,
        closeTo(62 / 36, .001),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
