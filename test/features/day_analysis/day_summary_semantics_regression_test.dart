import 'dart:convert';

import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_activity_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_dml_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_summary_snapshot_use_case.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/critical_day_context.dart';

Map<String, dynamic> summarySection(String text, String key) =>
    jsonDecode(
          text
              .split('\n')
              .singleWhere((line) => line.startsWith('$key '))
              .substring(key.length + 1),
        )
        as Map<String, dynamic>;
String summaryDml(DaySummarySnapshot snapshot) => const BuildDayDmlUseCase()(
  AcceptedDaySummary(snapshot: snapshot, acceptedAt: DateTime(2026, 9, 2, 9)),
).text;

void main() {
  for (final mode in ['missing', 'empty', 'partial', 'known']) {
    test(
      'rescue carbohydrates distinguish unavailable, observed empty and partial intake: $mode',
      () {
        final time = DateTime(2026, 9, 1, 12);
        final known = RecordedLowTreatment(
          mealId: 7,
          eatenAt: time,
          netCarbsGrams: 7.35,
        );
        final lows = mode == 'missing'
            ? null
            : mode == 'empty'
            ? <RecordedLowTreatment>[]
            : [
                known,
                RecordedLowTreatment(
                  mealId: 8,
                  eatenAt: time.add(const Duration(hours: 1)),
                  netCarbsGrams: mode == 'partial' ? null : 2.65,
                ),
              ];
        final snapshot = const BuildDaySummarySnapshotUseCase()(
          criticalDayContext(lows: lows),
          meals: [],
          lows: [],
        );
        final exported = summarySection(summaryDml(snapshot), 'LOW_TREATMENTS');
        expect(
          exported['confirmed_count'],
          mode == 'missing'
              ? null
              : mode == 'empty'
              ? 0
              : 2,
        );
        expect(
          exported['confirmed_carbs_g'],
          mode == 'missing' || mode == 'partial'
              ? null
              : mode == 'empty'
              ? 0
              : 10,
        );
        expect(
          snapshot.limitations.contains('lowTreatments'),
          mode == 'missing' || mode == 'partial',
        );
        expect(
          DaySummarySnapshot.decode(snapshot.encode()).metrics,
          snapshot.metrics,
        );
      },
    );
  }

  for (final mode in [
    'known',
    'missing_basal',
    'unobserved_basal',
    'missing_boluses',
  ]) {
    test(
      'LLM total insulin never implies zero delivery when a source is unavailable: $mode',
      () {
        final day = criticalDayContext(
          basalAvailable: mode != 'missing_basal',
          basalObserved: mode != 'unobserved_basal',
          bolusesAvailable: mode != 'missing_boluses',
        );
        final snapshot = const BuildDaySummarySnapshotUseCase()(
          day,
          meals: [],
          lows: [],
        );
        final insulin = summarySection(summaryDml(snapshot), 'INSULIN');
        expect(insulin['total_est_units'], mode == 'known' ? 7 : null);
        expect(
          insulin['bolus_total_units'],
          mode == 'missing_boluses' ? null : 3,
        );
        expect(
          insulin['basal_est_units'],
          mode == 'missing_basal' || mode == 'unobserved_basal' ? null : 4,
        );
        expect(insulin['smb_units'], mode == 'missing_boluses' ? null : 1);
        expect(insulin['smb_count'], mode == 'missing_boluses' ? null : 1);
        expect(
          summarySection(summaryDml(snapshot), 'NIGHT')['basal_est_units'],
          1,
        );
      },
    );
  }

  test(
    'a partial meal aggregate retains known values and an explicit limitation after archival and export',
    () {
      final snapshot = const BuildDaySummarySnapshotUseCase()(
        criticalDayContext(
          meals: const DayMealSummary(
            count: 3,
            plannedFallbackCount: 1,
            missingSnapshotCount: 1,
            netCarbs: 30,
            fat: 8,
            protein: 12,
          ),
        ),
        meals: [],
        lows: [],
      );
      final restored = DaySummarySnapshot.decode(snapshot.encode());
      final document = summaryDml(restored);
      expect(
        summarySection(document, 'MEALS'),
        containsPair('net_carbs_g', 30),
      );
      expect(summarySection(document, 'MEALS')['count'], 3);
      expect(
        summarySection(document, 'QUALITY')['limitations'],
        contains('meals'),
      );
      expect(restored.metrics[DaySummaryMetric.proteinGrams], 12);
    },
  );

  test(
    'activity, device ages and meal macros survive round-trip without mixing minutes, hours or portions',
    () {
      final snapshot = const BuildDaySummarySnapshotUseCase()(
        criticalDayContext(
          activities: [
            const DayActivitySummary(
              name: 'Walk',
              observedDuration: Duration(minutes: 20),
              ongoing: false,
            ),
            const DayActivitySummary(
              name: 'Cycle',
              observedDuration: Duration(minutes: 25),
              ongoing: true,
            ),
          ],
        ),
        meals: [],
        lows: [],
      );
      final restored = DaySummarySnapshot.decode(snapshot.encode());
      final document = summaryDml(restored);
      expect(summarySection(document, 'ACTIVITY')['minutes'], 45);
      expect(
        summarySection(document, 'DEVICES')['sensor_age_minutes_at_as_of'],
        2970,
      );
      expect(
        summarySection(document, 'DEVICES')['pod_age_minutes_at_as_of'],
        360,
      );
      expect(summarySection(document, 'MEALS')['net_carbs_g'], 45);
      expect(summarySection(document, 'MEALS')['protein_g'], 20);
      expect(summarySection(document, 'MEALS')['fat_g'], 12);
      expect(restored.metrics[DaySummaryMetric.glucoseMean], isNull);
      expect(summarySection(document, 'GLUCOSE')['mean_mg_dl'], isNull);
    },
  );
}
