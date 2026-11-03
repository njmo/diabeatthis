import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_history.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_analysis_dml_serializer.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_analysis_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_summary_snapshot_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/critical_day_context.dart';
import 'day_summary_semantics_regression_test.dart' show summarySection;

void main() {
  for (final missing in [
    null,
    'cgm',
    'treatments',
    'device_status',
    'low_treatments',
    'activities',
  ]) {
    test(
      'day JSON keeps accepted aggregates and masks only the unavailable source: $missing',
      () async {
        final day = criticalDayContext();
        final snapshot = const BuildDaySummarySnapshotUseCase()(
          day,
          meals: [],
          lows: [],
        );
        final archived = snapshot.encode();
        final accepted = AcceptedDaySummary(
          snapshot: snapshot,
          acceptedAt: DateTime(2026, 9, 2, 9),
        );
        final mealTime = DateTime(2026, 9, 1, 12);
        final end = DateTime(2026, 9, 2, 3);
        Glucose reading(DateTime at, int value) => Glucose(
          externalId: null,
          source: GlucoseSource.cloud,
          date: at,
          sgv: value,
          direction: 'Flat',
        );
        final history = DayAnalysisHistory(
          start: DateTime(2026, 8, 31),
          end: end,
          builtAt: DateTime(2026, 9, 2, 10),
          glucose: missing == 'cgm'
              ? null
              : [
                  reading(mealTime.subtract(const Duration(minutes: 5)), 110),
                  reading(mealTime, 120),
                  reading(mealTime.add(const Duration(minutes: 15)), 160),
                  reading(end.add(const Duration(minutes: 1)), 999),
                ],
          statuses: missing == 'device_status' ? null : [],
          treatments: missing == 'treatments'
              ? null
              : [
                  ManualBolus(
                    externalId: 'observed',
                    createdAt: mealTime.add(const Duration(minutes: 2)),
                    insulin: 2,
                  ),
                  ManualBolus(
                    externalId: 'future',
                    createdAt: end.add(const Duration(minutes: 1)),
                    insulin: 99,
                  ),
                ],
          meals: [
            DayAnalysisMeal(
              id: 1,
              name: 'Saved meal',
              eatenAt: mealTime,
              eatingEndedAt: mealTime.add(const Duration(minutes: 20)),
              wait: null,
              window: const Duration(minutes: 90),
              macroSource: 'consumed',
              macros: MealMacroSummary(
                carbsGrams: 30,
                netCarbsGrams: 22.5,
                fiberGrams: 7.5,
                fatGrams: 6,
                proteinGrams: 9,
                totalGrams: 150,
              ),
              ingredients: [(name: 'Recorded ingredient', grams: 150)],
              stages: [(status: 'eating', at: mealTime)],
            ),
          ],
          lows: missing == 'low_treatments' ? null : [],
          activities: missing == 'activities' ? null : [],
          failures: {if (missing != null) missing},
        );
        final context = await const BuildDayAnalysisContextUseCase()(
          accepted,
          history,
        );
        final document = serializeDayAnalysisContext(context);
        final meal = summarySection(document.text, 'MEAL');
        final outcome = meal['outcome'] as Map;
        expect(snapshot.encode(), archived);
        expect(summarySection(document.text, 'MEALS')['net_carbs_g'], 45);
        expect(summarySection(document.text, 'INSULIN')['total_est_units'], 7);
        expect(meal['macros'], {
          'net_carbs_g': 22.5,
          'fat_g': 6,
          'protein_g': 9,
        });
        expect(meal['recorded_wait_min'], isNull);
        expect(
          outcome['complete_window'],
          true,
          reason: 'An elapsed window is independent of source availability',
        );
        expect(outcome['max_mg_dl'], missing == 'cgm' ? null : 160);
        expect(outcome['has_cgm_observations'], missing == 'cgm' ? null : true);
        expect(outcome['bolus_total_u'], missing == 'treatments' ? null : 2);
        expect(outcome['smb_count'], missing == 'treatments' ? null : 0);
        expect(
          outcome['basal_u'],
          isNull,
          reason: 'Empty pump history must not establish zero basal delivery',
        );
        expect(
          summarySection(document.text, 'RESCUE_CARBS')['blocks'],
          missing == 'low_treatments' ? isNull : isEmpty,
        );
        expect(
          summarySection(document.text, 'ACTIVITY_EVENTS')['blocks'],
          missing == 'activities' ? isNull : isEmpty,
        );
        expect(
          summarySection(document.text, 'HISTORY')['failed_sources'],
          missing == null ? isEmpty : [missing],
        );
        expect(document.text, isNot(contains('999')));
        expect(document.text, isNot(contains('99.0')));
      },
    );
  }
}
