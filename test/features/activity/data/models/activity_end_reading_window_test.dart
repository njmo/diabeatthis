import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_analysis_data.dart';
import 'package:diabeatthis/features/activity/data/models/activity_session_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 28, 17);
  final end = DateTime(2026, 10, 28, 18);
  Glucose reading(int minute, int value) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)),
    sgv: value,
    direction: '',
  );
  ActivitySessionSummary summary(List<Glucose> readings) =>
      ActivitySessionSummary(
        ActivityLogAnalysisData(
          chartStart: start.subtract(const Duration(minutes: 30)),
          chartEnd: end.add(const Duration(hours: 3)),
          activityStart: start,
          activityEnd: end,
          glucoseReadings: readings,
          deviceStatuses: const [],
          chartTreatments: const [],
          activityTargets: const [],
          preActivityMeals: const [],
          deviceStatusAtStart: null,
        ),
      );

  test(
    'closer post-activity reading cannot replace the final in-activity reading',
    () {
      final result = summary([
        reading(0, 183),
        reading(55, 91),
        reading(64, 66),
      ]);
      expect(result.end?.sgv, 91);
      expect(result.end?.date, start.add(const Duration(minutes: 55)));
      expect(result.delta, -92);
      expect(result.during.last, result.end);
      expect(result.after.last.sgv, 66);
    },
  );

  test(
    'stale in-activity reading is shown as context, never a fresh endpoint',
    () {
      final result = summary([
        reading(0, 183),
        reading(54, 91),
        reading(64, 66),
      ]);
      expect(result.end, isNull);
      expect(result.delta, isNull);
      expect(result.lastDuring?.sgv, 91);
    },
  );

  test(
    'exact finish belongs to the chart and endpoint; future-only history stays unknown',
    () {
      final result = summary([
        reading(0, 183),
        reading(60, 80),
        reading(61, 66),
      ]);
      expect(result.end?.sgv, 80);
      expect(result.during.last.sgv, 80);
      expect(summary([reading(64, 66)]).end, isNull);
    },
  );
}
