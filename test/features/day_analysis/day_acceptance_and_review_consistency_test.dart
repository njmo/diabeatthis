import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_review_entry.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_recorded_meal.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/accept_day_summary_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_summary_snapshot_use_case.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_review_entry.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/critical_day_context.dart';
import '../../helpers/regression/scripted_read.dart';
import 'day_summary_semantics_regression_test.dart'
    show summaryDml, summarySection;

void main() {
  for (final change in ['macros', 'source_quality']) {
    test(
      'acceptance rejects stale $change even if glucose and observation dates did not change',
      () async {
        final preview = const BuildDaySummarySnapshotUseCase()(
          criticalDayContext(),
          meals: [],
          lows: [],
        );
        final current = DaySummarySnapshot.fromJson({
          ...preview.toJson(),
          'metrics': <String, dynamic>{
            ...preview.toJson()['metrics'] as Map,
            if (change == 'macros') 'netCarbsGrams': 50,
            if (change == 'source_quality') 'lowTreatmentCarbsGrams': null,
          },
          'limitations': [
            ...preview.limitations,
            if (change == 'source_quality') 'lowTreatments',
          ],
        });
        final reads = ScriptedRead<DaySummarySnapshot>('current summary', [
          (arguments: [], respond: () => current),
        ]);
        final saves = ScriptedRead<void>('accepted summary write', []);
        final useCase = AcceptDaySummaryUseCase(
          loadCurrent: () => reads([]),
          save: (value) => saves([value]),
          now: () => DateTime(2026, 9, 2, 10),
        );
        await expectLater(
          useCase(preview, skippedRecords: {}, acknowledgeLimitations: true),
          throwsA(isA<StaleDaySummary>()),
        );
        reads.verifyComplete();
        saves.verifyComplete();
        expect(preview.metrics[DaySummaryMetric.netCarbsGrams], 45);
        expect(preview.metrics[DaySummaryMetric.lowTreatmentCarbsGrams], 0);
      },
    );
  }

  test(
    'accepted summary preserves exact confirmed aggregates, limitations and acceptance time',
    () async {
      final preview = const BuildDaySummarySnapshotUseCase()(
        criticalDayContext(),
        meals: [],
        lows: [],
      );
      final archived = preview.encode();
      final now = DateTime(2026, 9, 2, 10);
      final reads = ScriptedRead<DaySummarySnapshot>('current summary', [
        (arguments: [], respond: () => preview),
      ]);
      final writes = <AcceptedDaySummary>[];
      final accepted = await AcceptDaySummaryUseCase(
        loadCurrent: () => reads([]),
        save: (value) async => writes.add(value),
        now: () => now,
      )(preview, skippedRecords: {}, acknowledgeLimitations: true);
      reads.verifyComplete();
      expect(writes, hasLength(1));
      expect(accepted.acceptedAt, now);
      expect(accepted.snapshot.encode(), archived);
      expect(
        summarySection(summaryDml(accepted.snapshot), 'MEALS')['net_carbs_g'],
        45,
      );
      expect(
        summarySection(
          summaryDml(accepted.snapshot),
          'INSULIN',
        )['total_est_units'],
        7,
      );
      expect(
        summarySection(summaryDml(accepted.snapshot), 'QUALITY')['limitations'],
        containsAll(['glucose', 'nightGlucose']),
      );
    },
  );

  test(
    'reconciliation records never become additional meals or consumed carbohydrates in the day totals',
    () {
      final at = DateTime(2026, 9, 1, 12);
      BolusWizard wizard(String? remote, String local) => BolusWizard(
        nightscoutObjectId: remote,
        localId: local,
        createdAt: at,
        date: null,
        glucose: 120,
        units: 'mg/dl',
        notes: null,
        calculatorResult: null,
      );
      final first = RecordedLowTreatment(
        mealId: 7,
        eatenAt: at,
        netCarbsGrams: 7.35,
      );
      final second = RecordedLowTreatment(
        mealId: 8,
        eatenAt: at.add(const Duration(hours: 1)),
        netCarbsGrams: 2.65,
      );
      final snapshot = const BuildDaySummarySnapshotUseCase()(
        criticalDayContext(lows: [first, second]),
        meals: [
          DayMealReviewEntry(
            meal: DayRecordedMeal(id: 1, name: 'Saved meal', eatenAt: at),
            wizards: [wizard('remote-wizard', 'local-linked')],
            assignments: [],
          ),
          DayMealReviewEntry(
            meal: null,
            wizards: [wizard(null, 'local-unlinked')],
            assignments: [],
          ),
        ],
        lows: [
          LowTreatmentReviewEntry(
            event: Treat(
              externalId: 'linked-receipt',
              createdAt: at,
              carbs: 12,
            ),
            recorded: first,
          ),
          LowTreatmentReviewEntry(
            event: Treat(
              externalId: 'unresolved-receipt',
              createdAt: at,
              carbs: 20,
            ),
          ),
          LowTreatmentReviewEntry(
            event: Treat(
              externalId: 'dismissed-receipt',
              createdAt: at,
              carbs: 30,
            ),
            dismissed: true,
          ),
          LowTreatmentReviewEntry(recorded: second),
        ],
      );
      expect(snapshot.review.map((row) => row.sourceId), [
        'remote-wizard',
        'local-unlinked',
        'linked-receipt',
        'unresolved-receipt',
        'dismissed-receipt',
      ]);
      expect(snapshot.review.map((row) => row.resolution), [
        DaySummaryResolution.linked,
        DaySummaryResolution.unresolved,
        DaySummaryResolution.linked,
        DaySummaryResolution.unresolved,
        DaySummaryResolution.dismissed,
      ]);
      expect(snapshot.review.map((row) => row.mealId), [
        1,
        null,
        7,
        null,
        null,
      ]);
      final exported = summaryDml(DaySummarySnapshot.decode(snapshot.encode()));
      expect(
        summarySection(exported, 'LOW_TREATMENTS')['confirmed_carbs_g'],
        10,
      );
      expect(summarySection(exported, 'LOW_TREATMENTS')['confirmed_count'], 2);
      expect(summarySection(exported, 'MEALS')['count'], 2);
      expect(summarySection(exported, 'MEALS')['net_carbs_g'], 45);
    },
  );
}
