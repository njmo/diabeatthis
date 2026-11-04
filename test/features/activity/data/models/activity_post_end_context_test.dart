import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_analysis_data.dart';
import 'package:diabeatthis/features/activity/data/models/activity_session_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 28, 17);
  final end = start.add(const Duration(hours: 1));
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
          chartStart: start,
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
    'closer later reading extends overview while preserving in-activity statistics',
    () {
      final result = summary([
        reading(0, 183),
        reading(55, 91),
        reading(64, 66),
      ]);
      expect(result.displayEnd?.sgv, 66);
      expect(result.displayEndIsAfter, isTrue);
      expect(result.overviewChartEnd, start.add(const Duration(minutes: 64)));
      expect(result.overviewReadings.last.sgv, 66);
      expect(result.displayDelta, -117);
      expect(result.end?.sgv, 91);
      expect(result.period.window.minimum?.sgv, 91);
      expect(result.during.map((entry) => entry.sgv), [183, 91]);
    },
  );

  test('later fallback allows ten minutes, rejects stale later samples', () {
    expect(summary([reading(0, 183), reading(70, 66)]).displayEnd?.sgv, 66);
    final stale = summary([reading(0, 183), reading(71, 66)]);
    expect(stale.displayEnd, isNull);
    expect(stale.overviewChartEnd, end);
  });

  test('exact finish and equally near earlier reading take precedence', () {
    final exact = summary([reading(60, 90), reading(61, 66)]);
    expect(exact.displayEnd?.sgv, 90);
    expect(exact.displayEndIsAfter, isFalse);
    final tie = summary([reading(56, 91), reading(64, 66)]);
    expect(tie.displayEnd?.sgv, 91);
  });
}
