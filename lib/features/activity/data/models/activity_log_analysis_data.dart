import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../../core/domain/model/treatment_base.dart';

class ActivityLogAnalysisData {
  static const int activityTargetTop = 140;

  final DateTime chartStart;
  final DateTime chartEnd;
  final DateTime activityStart;
  final DateTime activityEnd;
  final List<Glucose> glucoseReadings;
  final List<Treatment> chartTreatments;
  final List<TemporaryTarget> activityTargets;
  final List<Meal> preActivityMeals;
  final DeviceStatus? deviceStatusAtStart;

  const ActivityLogAnalysisData({
    required this.chartStart,
    required this.chartEnd,
    required this.activityStart,
    required this.activityEnd,
    required this.glucoseReadings,
    required this.chartTreatments,
    required this.activityTargets,
    required this.preActivityMeals,
    required this.deviceStatusAtStart,
  });

  int? get glucoseAtStart => _nearestGlucose(activityStart)?.sgv;

  double? get iobAtStart => deviceStatusAtStart?.iob;

  double? get averageGlucoseDuringActivity {
    final values = _glucoseDuringActivity.map((g) => g.sgv).toList();
    if (values.isEmpty) return null;
    final sum = values.fold<int>(0, (previous, value) => previous + value);
    return sum / values.length;
  }

  int? get minGlucoseDuringActivity {
    final values = _glucoseDuringActivity.map((g) => g.sgv).toList();
    if (values.isEmpty) return null;
    values.sort();
    return values.first;
  }

  int? get maxGlucoseDuringActivity {
    final values = _glucoseDuringActivity.map((g) => g.sgv).toList();
    if (values.isEmpty) return null;
    values.sort();
    return values.last;
  }

  List<Treat> get treatsDuringActivity {
    return chartTreatments.whereType<Treat>().where((treat) {
      final createdAt = treat.createdAt;
      return _isBetween(createdAt, activityStart, activityEnd);
    }).toList();
  }

  int get treatCarbsDuringActivity {
    return treatsDuringActivity.fold<int>(
      0,
      (previous, treat) => previous + treat.carbs,
    );
  }

  Iterable<Glucose> get _glucoseDuringActivity {
    return glucoseReadings.where((glucose) {
      return _isBetween(glucose.date, activityStart, activityEnd);
    });
  }

  Glucose? _nearestGlucose(DateTime date) {
    Glucose? nearest;
    int? bestDistanceMs;

    for (final glucose in glucoseReadings) {
      final distanceMs = glucose.date.difference(date).inMilliseconds.abs();
      if (bestDistanceMs == null || distanceMs < bestDistanceMs) {
        bestDistanceMs = distanceMs;
        nearest = glucose;
      }
    }

    if (bestDistanceMs == null || bestDistanceMs > 15 * 60 * 1000) {
      return null;
    }
    return nearest;
  }

  bool _isBetween(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }
}
