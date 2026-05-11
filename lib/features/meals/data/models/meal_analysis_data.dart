import '../../../../core/domain/model/correction_bolus.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../../core/domain/model/treatment_base.dart';

class MealAnalysisData {
  final DateTime chartStart;
  final DateTime chartEnd;
  final DateTime eventStart;
  final DateTime eventEnd;
  final DateTime mealTime;
  final List<Glucose> glucoseReadings;
  final List<Treatment> treatments;
  final List<DeviceStatus> deviceStatuses;
  final List<MealLinkedActivityData> linkedActivities;
  final List<MealLinkedMealData> linkedMeals;
  final List<MealTimelineEventData> timelineEvents;

  const MealAnalysisData({
    required this.chartStart,
    required this.chartEnd,
    required this.eventStart,
    required this.eventEnd,
    required this.mealTime,
    required this.glucoseReadings,
    required this.treatments,
    required this.deviceStatuses,
    required this.linkedActivities,
    required this.linkedMeals,
    required this.timelineEvents,
  });

  GlucoseStatsData get glucoseStats {
    final values = glucoseReadings.map((g) => g.sgv).toList();
    if (values.isEmpty) {
      return const GlucoseStatsData.empty();
    }

    values.sort();
    final sum = values.fold<int>(0, (previous, value) => previous + value);
    final peak = glucoseReadings.reduce(
      (best, item) => item.sgv > best.sgv ? item : best,
    );
    final first = glucoseReadings.first;
    final last = glucoseReadings.last;
    final inRange = glucoseReadings
        .where((g) => g.sgv >= 70 && g.sgv <= 180)
        .length;
    final aboveRange = glucoseReadings.where((g) => g.sgv > 180).length;
    final belowRange = glucoseReadings.where((g) => g.sgv < 70).length;

    return GlucoseStatsData(
      averageGlucose: sum / values.length,
      minGlucose: values.first,
      maxGlucose: values.last,
      peakGlucose: peak.sgv,
      timeToPeak: peak.date.difference(mealTime),
      timeInRangePercent: inRange / glucoseReadings.length * 100,
      timeAboveRangePercent: aboveRange / glucoseReadings.length * 100,
      timeBelowRangePercent: belowRange / glucoseReadings.length * 100,
      glucoseDelta: last.sgv - first.sgv,
      glucoseRateMgDlPerMinute: _rate(first, last),
    );
  }

  double? get latestCob {
    if (deviceStatuses.isEmpty) return null;
    return deviceStatuses.last.cob;
  }

  double? get latestIob {
    if (deviceStatuses.isEmpty) return null;
    return deviceStatuses.last.iob;
  }

  double get totalInsulinUnits {
    return treatments.fold<double>(0, (sum, treatment) {
      if (treatment is ManualBolus) {
        return sum + treatment.insulin;
      }
      if (treatment is CorrectionBolus) {
        return sum + treatment.insulin;
      }
      if (treatment is Meal) {
        return sum + (treatment.insulin ?? 0);
      }
      return sum;
    });
  }

  int get totalTreatmentCarbs {
    return treatments.fold<int>(0, (sum, treatment) {
      if (treatment is Treat) {
        return sum + treatment.carbs;
      }
      if (treatment is Meal) {
        return sum + (treatment.carbs ?? 0);
      }
      return sum;
    });
  }

  static double? _rate(Glucose first, Glucose last) {
    final minutes = last.date.difference(first.date).inMinutes;
    if (minutes == 0) return null;
    return (last.sgv - first.sgv) / minutes;
  }
}

class GlucoseStatsData {
  final double? averageGlucose;
  final int? minGlucose;
  final int? maxGlucose;
  final int? peakGlucose;
  final Duration? timeToPeak;
  final double? timeInRangePercent;
  final double? timeAboveRangePercent;
  final double? timeBelowRangePercent;
  final int? glucoseDelta;
  final double? glucoseRateMgDlPerMinute;

  const GlucoseStatsData({
    required this.averageGlucose,
    required this.minGlucose,
    required this.maxGlucose,
    required this.peakGlucose,
    required this.timeToPeak,
    required this.timeInRangePercent,
    required this.timeAboveRangePercent,
    required this.timeBelowRangePercent,
    required this.glucoseDelta,
    required this.glucoseRateMgDlPerMinute,
  });

  const GlucoseStatsData.empty()
    : averageGlucose = null,
      minGlucose = null,
      maxGlucose = null,
      peakGlucose = null,
      timeToPeak = null,
      timeInRangePercent = null,
      timeAboveRangePercent = null,
      timeBelowRangePercent = null,
      glucoseDelta = null,
      glucoseRateMgDlPerMinute = null;

  bool get hasValues => averageGlucose != null;
}

class MealLinkedActivityData {
  final int activityLogId;
  final String activityName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? intensity;
  final String? notes;

  const MealLinkedActivityData({
    required this.activityLogId,
    required this.activityName,
    required this.startedAt,
    required this.endedAt,
    required this.intensity,
    required this.notes,
  });
}

class MealLinkedMealData {
  final int mealId;
  final String name;
  final DateTime plannedAt;
  final String status;

  const MealLinkedMealData({
    required this.mealId,
    required this.name,
    required this.plannedAt,
    required this.status,
  });
}

class MealTimelineEventData {
  final DateTime timestamp;
  final MealTimelineEventType type;
  final String label;
  final String? value;
  final int? activityLogId;
  final int? mealId;

  const MealTimelineEventData({
    required this.timestamp,
    required this.type,
    required this.label,
    this.value,
    this.activityLogId,
    this.mealId,
  });
}

enum MealTimelineEventType {
  mealStatus,
  insulin,
  carbs,
  correction,
  activity,
  meal,
  deviceStatus,
}

class MealSnapshotComparisonRowData {
  final String label;
  final double? plannedValue;
  final double? consumedValue;
  final String unit;

  const MealSnapshotComparisonRowData({
    required this.label,
    required this.plannedValue,
    required this.consumedValue,
    required this.unit,
  });

  double? get difference {
    final planned = plannedValue;
    final consumed = consumedValue;
    if (planned == null || consumed == null) return null;
    return consumed - planned;
  }
}
