import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/domain/model/net_carbs_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealMacroSummary', () {
    test('uses provided net carbs for mixed-source meal totals', () {
      final summary = MealMacroSummary(
        carbsGrams: 0.5,
        fatGrams: 1.5,
        proteinGrams: 1,
        fiberGrams: 2.5,
        totalGrams: 50,
        netCarbsGrams: 0,
      );

      expect(summary.netCarbsGrams, 0);
      expect(summary.totalKcal, 17.5);
    });
  });

  group('calculateNetCarbs', () {
    test('uses carbs as net carbs for UE labels', () {
      expect(
        calculateNetCarbs(carbs: 12, fiber: 3, labelMode: CarbsLabelMode.eu),
        12,
      );
    });

    test('subtracts fiber and clamps below zero for non-UE labels', () {
      expect(
        calculateNetCarbs(carbs: 1, fiber: 5, labelMode: CarbsLabelMode.nonEu),
        0,
      );
    });
  });
}
