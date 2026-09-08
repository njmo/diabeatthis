import 'package:diabeatthis/core/domain/model/bolus_calculator_result.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealAnalysisData', () {
    test('does not count bolus wizard total insulin as delivered insulin', () {
      final analysis = _analysis(
        treatments: [
          _bolusWizard(carbs: 24, totalInsulin: 1.8),
          ManualBolus(
            externalId: 'manual-bolus',
            createdAt: _now,
            insulin: 1.1,
          ),
          CorrectionBolus(
            externalId: 'correction-bolus',
            createdAt: _now,
            insulin: 0.4,
          ),
        ],
      );

      expect(analysis.totalInsulinUnits, 1.5);
    });

    test('ignores invalid and out-of-window insulin deliveries', () {
      final analysis = _analysis(
        treatments: [
          ManualBolus(
            externalId: 'invalid',
            createdAt: _now,
            insulin: 5,
            isValid: false,
          ),
          ManualBolus(
            externalId: 'outside',
            createdAt: _now.subtract(const Duration(minutes: 1)),
            insulin: 5,
          ),
          CorrectionBolus(externalId: 'valid', createdAt: _now, insulin: 0.4),
        ],
      );
      expect(analysis.totalInsulinUnits, 0.4);
    });

    test(
      'total insulin shares positive finite dose rules with correction summary',
      () {
        final analysis = _analysis(
          treatments: [
            ManualBolus(externalId: 'negative', createdAt: _now, insulin: -1),
            CorrectionBolus(
              externalId: 'non-finite',
              createdAt: _now,
              insulin: double.nan,
            ),
            ManualBolus(externalId: 'valid', createdAt: _now, insulin: 0.05),
          ],
        );
        expect(analysis.totalInsulinUnits, 0.05);
      },
    );

    test('still counts bolus wizard carbs in treatment carbs', () {
      final analysis = _analysis(
        treatments: [
          _bolusWizard(carbs: 24, totalInsulin: 1.8),
          Treat(externalId: 'carbs', createdAt: _now, carbs: 6),
        ],
      );

      expect(analysis.totalTreatmentCarbs, 30);
    });
  });
}

final _now = DateTime(2026, 5, 20, 12);

MealAnalysisData _analysis({List<Treatment> treatments = const []}) {
  return MealAnalysisData(
    chartStart: _now,
    chartEnd: _now,
    expectedChartEnd: _now,
    eventStart: _now,
    eventEnd: _now,
    mealTime: _now,
    glucoseReadings: const [],
    treatments: treatments,
    temporaryTargets: const [],
    deviceStatuses: const [],
    linkedActivities: const [],
    linkedMeals: const [],
    timelineEvents: const [],
  );
}

BolusWizard _bolusWizard({
  required double carbs,
  required double totalInsulin,
}) {
  return BolusWizard(
    nightscoutObjectId: 'wizard',
    createdAt: _now,
    date: _now,
    glucose: 120,
    units: 'mg/dl',
    notes: null,
    calculatorResult: BolusCalculatorResult(
      basalIob: null,
      bolusIob: null,
      carbs: carbs,
      carbsInsulin: null,
      cob: null,
      cobInsulin: null,
      dateCreated: _now,
      glucoseDifference: null,
      glucoseInsulin: null,
      glucoseTrend: null,
      glucoseValue: null,
      ic: null,
      id: null,
      isf: null,
      note: null,
      otherCorrection: null,
      percentageCorrection: null,
      profileName: null,
      superbolusInsulin: null,
      targetBGHigh: null,
      targetBGLow: null,
      timestamp: _now,
      totalInsulin: totalInsulin,
      trendInsulin: null,
      utcOffset: null,
      version: null,
      wasBasalIOBUsed: null,
      wasBolusIOBUsed: null,
      wasCOBUsed: null,
      wasGlucoseUsed: null,
      wasSuperbolusUsed: null,
      wasTempTargetUsed: null,
      wasTrendUsed: null,
      wereCarbsUsed: null,
    ),
  );
}
