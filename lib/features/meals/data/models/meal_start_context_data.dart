import '../../../../common/history/latest_reading_at.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import 'meal_analysis_data.dart';
import 'meal_details_data.dart';

class MealStartContextData {
  final MealDetailsData details;
  final MealAnalysisData analysis;

  const MealStartContextData({required this.details, required this.analysis});

  DateTime get referenceTime => details.analysisTime;
  bool get hasRecordedStart => details.recordedEatingStartedAt != null;

  Glucose? get glucose =>
      latestReadingAt(analysis.glucoseReadings, referenceTime, (g) => g.date);
  DeviceStatus? get deviceStatus =>
      latestReadingAt(analysis.deviceStatuses, referenceTime, (s) => s.date);

  /// This is the last recorded manual bolus, not inferred meal attribution.
  ManualBolus? get precedingBolus => latestReadingAt(
    analysis.treatments.whereType<ManualBolus>().where(
      (bolus) => bolus.isValid,
    ),
    referenceTime,
    (bolus) => bolus.createdAt,
    maxAge: const Duration(hours: 1),
  );

  Duration? get bolusToStart => hasRecordedStart && precedingBolus != null
      ? referenceTime.difference(precedingBolus!.createdAt)
      : null;

  /// Elapsed application status time is distinct from a recorded insulin dose.
  Duration? get recordedWait {
    if (!hasRecordedStart) return null;
    final waiting =
        details.statusHistory
            .where(
              (entry) =>
                  entry.status == 'bolused-waiting' &&
                  !entry.createdAt.isAfter(referenceTime),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return waiting.isEmpty
        ? null
        : referenceTime.difference(waiting.last.createdAt);
  }
}
