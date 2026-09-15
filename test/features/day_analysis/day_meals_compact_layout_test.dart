import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_macro_legend.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meals_overview.dart';
import 'package:diabeatthis/features/meals/common/widgets/meal_macro_donut.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('phone layout keeps legend beside chart and counts in one row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: DayMealsOverview(
                mealCount: 6,
                netCarbs: 131.6,
                protein: 77.3,
                fat: 79.4,
                lowCount: 0,
                lowCarbs: 0,
              ),
            ),
          ),
        ),
      ),
    );
    final chart = tester.getRect(find.byType(MealMacroDonut));
    final legend = tester.getRect(find.byType(DayMacroLegend));
    expect(legend.left, greaterThan(chart.right));
    expect(legend.top, lessThan(chart.bottom));
    final meals = tester.getTopLeft(find.text('Posiłki'));
    final lows = tester.getTopLeft(find.text('Dosłodzenia'));
    final carbs = tester.getTopLeft(find.text('WW z dosłodzeń'));
    expect(lows.dy, meals.dy);
    expect(carbs.dy, meals.dy);
    expect(tester.getSize(find.byType(DayMealsOverview)).height, lessThan(300));
    expect(tester.takeException(), isNull);
  });
}
