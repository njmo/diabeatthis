import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/glucose_rise_summary.dart';
import '../../../../common/history/latest_reading_at.dart';
import '../../../../common/history/nearest_cgm_reading.dart';
import '../../../../core/domain/model/correction_bolus.dart';
import '../../../../core/domain/model/glucose.dart';
import 'activity_log_analysis_data.dart';

/// Retrospective recorded facts, never dosing recommendations.
class ActivitySessionSummary {
  final ActivityLogAnalysisData data;
  const ActivitySessionSummary(this.data);

  List<Glucose> readingsBetween(DateTime start, DateTime end) {
    final readings = <DateTime, Glucose>{
      for (final reading in data.glucoseReadings)
        if (reading.type == GlucoseType.cgm &&
            reading.sgv > 0 &&
            !reading.date.isBefore(start) &&
            !reading.date.isAfter(end))
          reading.date: reading,
    }.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return readings;
  }

  List<Glucose> get during =>
      readingsBetween(data.activityStart, data.activityEnd);
  List<Glucose> get after => readingsBetween(data.activityEnd, data.chartEnd);
  Glucose? get start =>
      nearestCgmReading(data.glucoseReadings, data.activityStart);
  // The endpoint must belong to the same activity window as its chart.
  Glucose? get end => latestReadingAt(during, data.activityEnd, (g) => g.date);
  Glucose? get lastDuring => during.lastOrNull;

  /// Display context may use the first later CGM sample, but this sample never
  /// becomes part of the training's mean, range, coverage or measured endpoint.
  Glucose? get displayEnd {
    final before = end;
    final later = readingsBetween(
      data.activityEnd,
      data.activityEnd.add(const Duration(minutes: 10)),
    ).where((reading) => reading.date.isAfter(data.activityEnd)).firstOrNull;
    if (later == null) return before;
    if (before == null ||
        later.date.difference(data.activityEnd) <
            data.activityEnd.difference(before.date)) {
      return later;
    }
    return before;
  }

  bool get displayEndIsAfter =>
      displayEnd?.date.isAfter(data.activityEnd) ?? false;
  int? get displayDelta =>
      start == null || displayEnd == null ? null : displayEnd!.sgv - start!.sgv;
  DateTime get overviewChartEnd =>
      displayEndIsAfter ? displayEnd!.date : data.activityEnd;
  List<Glucose> get overviewReadings =>
      readingsBetween(data.activityStart, overviewChartEnd);
  int? get delta => start == null || end == null ? null : end!.sgv - start!.sgv;
  GlucosePeriodSummary get period => GlucosePeriodSummary.calculate(
    data.glucoseReadings,
    data.activityStart,
    data.activityEnd,
  );
  GlucoseRiseSummary get firstRise => GlucoseRiseSummary.fromReadings(after);

  List<CorrectionBolus> corrections({required bool afterActivity}) =>
      data.chartTreatments.whereType<CorrectionBolus>().where((bolus) {
        if (!bolus.isValid || !bolus.insulin.isFinite || bolus.insulin <= 0) {
          return false;
        }
        return afterActivity
            ? bolus.createdAt.isAfter(data.activityEnd) &&
                  !bolus.createdAt.isAfter(data.chartEnd)
            : !bolus.createdAt.isBefore(data.activityStart) &&
                  !bolus.createdAt.isAfter(data.activityEnd);
      }).toList();

  double correctionUnits({required bool afterActivity}) => corrections(
    afterActivity: afterActivity,
  ).fold(0, (sum, bolus) => sum + bolus.insulin);

  bool get hasFreshDeviceStatus {
    final status = data.deviceStatusAtStart;
    if (status == null || status.date.isAfter(data.activityStart)) return false;
    return data.activityStart.difference(status.date) <=
        const Duration(minutes: 15);
  }

  bool get targetAtStart => data.activityTargets.any(
    (target) =>
        target.isValid &&
        !target.createdAt.isAfter(data.activityStart) &&
        target.createdAt
            .add(Duration(minutes: target.duration))
            .isAfter(data.activityStart),
  );
  bool get targetBefore => data.activityTargets.any(
    (target) =>
        target.isValid &&
        target.createdAt.isBefore(data.activityStart) &&
        target.createdAt
            .add(Duration(minutes: target.duration))
            .isAfter(data.chartStart),
  );
}
