import '../../../../common/analysis/dml_timestamp.dart';
import '../../../meals/domain/models/recorded_meal_timing.dart';

/// Explicit workflow roles shared by standalone meal and day analysis.
/// Missing stages remain unknown even when the meal has a fallback reference time.
Map<String, Object?> recordedMealTimingDml(
  List<({String status, DateTime at})> stages,
) {
  final timing = RecordedMealTiming(stages);
  String? at(DateTime? value) => value == null ? null : dmlTimestamp(value);
  return {
    'waiting_started_at': at(timing.recordedWaitStartedAt),
    'eating_started_at': at(timing.recordedEatingStartedAt),
    'eating_ended_at': at(timing.recordedEatingEndedAt),
  };
}
