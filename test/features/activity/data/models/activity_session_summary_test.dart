import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_analysis_data.dart';
import 'package:diabeatthis/features/activity/data/models/activity_session_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 3, 15);
  final end = start.add(const Duration(minutes: 45));
  Glucose reading(int minute, int value) => Glucose(
    externalId: null, source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)), sgv: value, direction: '',
  );
  ActivitySessionSummary summary({List<Glucose> readings = const []}) =>
      ActivitySessionSummary(ActivityLogAnalysisData(
        chartStart: start.subtract(const Duration(minutes: 30)),
        chartEnd: end.add(const Duration(hours: 3)),
        activityStart: start, activityEnd: end, glucoseReadings: readings,
        deviceStatuses: const [], activityTargets: const [],
        preActivityMeals: const [], deviceStatusAtStart: null,
        chartTreatments: [
          for (final minute in [-1, 0, 45, 46, 225, 226])
            CorrectionBolus(externalId: '$minute',
              createdAt: start.add(Duration(minutes: minute)), insulin: 0.1),
          CorrectionBolus(externalId: 'invalid', createdAt: start,
            insulin: 1, isValid: false),
        ],
      ));

  test('corrections at finish count only during, and respect observation end', () {
    final result = summary();
    expect(result.corrections(afterActivity: false).length, 2);
    expect(result.corrections(afterActivity: true).length, 2);
    expect(result.correctionUnits(afterActivity: false), closeTo(0.2, 0.001));
  });

  test('missing or stale endpoints remain unknown', () {
    expect(summary().delta, isNull);
    final result = summary(readings: [reading(-10, 100), reading(35, 140)]);
    expect(result.start, isNull);
    expect(result.end, isNull);
    expect(result.delta, isNull);
  });

  test('endpoints use nearby CGM with explicit timestamps', () {
    final result = summary(readings: [reading(-2, 100), reading(44, 125)]);
    expect(result.start?.date, start.subtract(const Duration(minutes: 2)));
    expect(result.end?.sgv, 125);
    expect(result.delta, 25);
  });

  test('rise detection sorts readings, excludes pre-finish samples and gaps', () {
    final result = summary(readings: [reading(60, 130), reading(50, 110),
      reading(55, 120), reading(0, 80), reading(45, 100)]);
    expect(result.firstRise.startedAt, end);
    final gap = summary(readings: [reading(45, 100), reading(55, 120), reading(60, 130)]);
    expect(gap.firstRise.startedAt, isNull);
  });
}
