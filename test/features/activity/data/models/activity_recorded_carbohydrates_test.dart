import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_analysis_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'during-activity totals include recorded formats and exclude duplicate components',
    () {
      final start = DateTime(2026);
      final at = start.add(const Duration(minutes: 10));
      final component = Treat(
        externalId: 'component',
        createdAt: at,
        carbs: 20,
      );
      final analysis = ActivityLogAnalysisData(
        chartStart: start,
        chartEnd: start.add(const Duration(hours: 3)),
        activityStart: start,
        activityEnd: start.add(const Duration(hours: 1)),
        glucoseReadings: [],
        deviceStatuses: [],
        activityTargets: [],
        preActivityMeals: [],
        deviceStatusAtStart: null,
        chartTreatments: [
          ExtendedCarb(
            externalId: 'immediate',
            createdAt: at,
            carbs: 15,
            duration: 0,
          ),
          ExtendedCarb(
            externalId: 'extended',
            createdAt: at,
            carbs: 60,
            duration: 60,
          ),
          component,
          BolusWizard(
            nightscoutObjectId: 'wizard',
            createdAt: at,
            date: at,
            glucose: 100,
            units: 'mg/dl',
            notes: null,
            calculatorResult: null,
            carbohydrateRecord: component,
          ),
        ],
      );
      expect(analysis.treatCarbsDuringActivity, 35);
      expect(analysis.treatsDuringActivity, hasLength(2));
    },
  );
}
