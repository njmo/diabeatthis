import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/features/meals/data/models/meal_advice_history_comparison.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 9, 12);
  MealAdviceHistoryComparison comparison({bool includeDelivery = true}) =>
      MealAdviceHistoryComparison(
        MealAnalysisData(
          chartStart: now,
          chartEnd: now.add(const Duration(hours: 1)),
          expectedChartEnd: now.add(const Duration(hours: 6)),
          eventStart: now,
          eventEnd: now.add(const Duration(hours: 1)),
          mealTime: now,
          glucoseReadings: [],
          temporaryTargets: [],
          deviceStatuses: [],
          linkedActivities: [],
          linkedMeals: [],
          timelineEvents: [],
          treatments: [
            BolusWizard(
              nightscoutObjectId: 'wizard',
              createdAt: now,
              date: now,
              glucose: 120,
              units: 'mg/dl',
              notes: null,
              calculatorResult: null,
            ),
            if (includeDelivery)
              ManualBolus(
                externalId: 'dose',
                createdAt: now.add(const Duration(seconds: 5)),
                insulin: 1,
              ),
            ManualBolus(
              externalId: 'invalid',
              createdAt: now,
              insulin: 10,
              isValid: false,
            ),
            ManualBolus(
              externalId: 'before',
              createdAt: now.subtract(const Duration(seconds: 1)),
              insulin: 20,
            ),
            ManualBolus(
              externalId: 'after',
              createdAt: now.add(const Duration(hours: 2)),
              insulin: 30,
            ),
            ManualBolus(externalId: 'zero', createdAt: now, insulin: 0),
          ],
        ),
      );
  test('wizard alone is not evidence of delivered insulin', () {
    final value = comparison(includeDelivery: false);
    expect(value.wizards, hasLength(1));
    expect(value.wizards.single.calculatorResult, isNull);
    expect(value.deliveries, isEmpty);
    expect(value.insulin.units, 0);
  });
  test('only valid positive deliveries inside window are counted', () {
    final value = comparison();
    expect(value.deliveries, hasLength(1));
    expect(value.deliveries.single.externalId, 'dose');
    expect(value.insulin.units, 1);
  });
}
