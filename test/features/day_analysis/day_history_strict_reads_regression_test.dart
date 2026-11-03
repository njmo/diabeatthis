import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal_batch.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/previous_days_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/load_day_analysis_history_use_case.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_activity_context.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_read.dart';
import 'day_dml_test.dart' show dmlFixture;

void main() {
  for (final failure in [
    null,
    'cgm',
    'device_status',
    'treatments',
    'meals',
    'low_treatments',
    'activities',
    'previous_days',
  ]) {
    test(
      'day context preserves available sources and exact date window; failure=$failure',
      () async {
        final accepted = dmlFixture();
        final start = DateTime.utc(2026, 10, 23, 20);
        final end = DateTime.utc(2026, 10, 26, 2);
        T response<T>(String source, T value) {
          if (source == failure) throw StateError('Scripted $source failure');
          return value;
        }

        final glucose = ScriptedRead<List<Glucose>>('cgm', [
          (
            arguments: [start, end],
            respond: () => response('cgm', <Glucose>[]),
          ),
        ]);
        final statuses = ScriptedRead<List<DeviceStatus>>('device_status', [
          (
            arguments: [start, end],
            respond: () => response('device_status', <DeviceStatus>[]),
          ),
        ]);
        final treatments = ScriptedRead<List<Treatment>>('treatments', [
          (
            arguments: [start, end],
            respond: () => response('treatments', <Treatment>[]),
          ),
        ]);
        final meals = ScriptedRead<DayAnalysisMealBatch>('meals', [
          (
            arguments: [start, end],
            respond: () => response('meals', DayAnalysisMealBatch(meals: [])),
          ),
        ]);
        final lows = ScriptedRead<List<RecordedLowTreatment>>(
          'low_treatments',
          [
            (
              arguments: [start, end],
              respond: () =>
                  response('low_treatments', <RecordedLowTreatment>[]),
            ),
          ],
        );
        final activities = ScriptedRead<List<MealActivityContext>>(
          'activities',
          [
            (
              arguments: [start, end],
              respond: () => response('activities', <MealActivityContext>[]),
            ),
          ],
        );
        final previous = ScriptedRead<PreviousDaysContext>('previous days', [
          (
            arguments: ['2026-10-25'],
            respond: () => response(
              'previous_days',
              PreviousDaysContext(
                startDayKey: '2026-10-18',
                endDayKeyExclusive: '2026-10-25',
                summaries: [],
              ),
            ),
          ),
        ]);
        final result = await LoadDayAnalysisHistoryUseCase(
          loadGlucose: (a, b) => glucose([a, b]),
          loadStatuses: (a, b) => statuses([a, b]),
          loadTreatments: (a, b) => treatments([a, b]),
          loadMeals: (a, b) => meals([a, b]),
          loadLows: (a, b) => lows([a, b]),
          loadActivities: (a, b) => activities([a, b]),
          loadPreviousDays: (day) => previous([day]),
          now: () => DateTime.utc(2026, 10, 26, 10),
        )(accepted);
        glucose.verifyComplete();
        statuses.verifyComplete();
        treatments.verifyComplete();
        meals.verifyComplete();
        lows.verifyComplete();
        activities.verifyComplete();
        previous.verifyComplete();
        expect(result.start, start);
        expect(result.end, end);
        expect(result.failures, failure == null ? isEmpty : {failure});
        expect(result.glucose, failure == 'cgm' ? isNull : isEmpty);
        expect(result.statuses, failure == 'device_status' ? isNull : isEmpty);
        expect(result.treatments, failure == 'treatments' ? isNull : isEmpty);
        expect(result.meals, failure == 'meals' ? isNull : isEmpty);
        expect(result.lows, failure == 'low_treatments' ? isNull : isEmpty);
        expect(result.activities, failure == 'activities' ? isNull : isEmpty);
        expect(
          result.previousDays?.summaries,
          failure == 'previous_days' ? isNull : isEmpty,
        );
        expect(
          accepted.snapshot.metrics.values.whereType<num>(),
          contains(123.5),
        );
      },
    );
  }
}
