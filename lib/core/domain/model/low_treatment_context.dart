import 'package:freezed_annotation/freezed_annotation.dart';

part 'low_treatment_context.freezed.dart';

enum LowTreatmentContextSource {
  manual('manual'),
  aapsSuggestion('aapsSuggestion'),
  dashboardAction('dashboardAction');

  const LowTreatmentContextSource(this.storageValue);

  final String storageValue;

  static LowTreatmentContextSource fromStorage(String value) {
    return LowTreatmentContextSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => LowTreatmentContextSource.manual,
    );
  }
}

enum LowTreatmentReason {
  carbsReq('carbsReq'),
  lowGlucose('lowGlucose'),
  fallingTrend('fallingTrend'),
  bgMismatch('bgMismatch'),
  unplannedActivity('unplannedActivity'),
  plannedActivity('plannedActivity'),
  symptoms('symptoms'),
  manual('manual'),
  other('other');

  const LowTreatmentReason(this.storageValue);

  final String storageValue;

  static LowTreatmentReason fromStorage(String value) {
    return LowTreatmentReason.values.firstWhere(
      (reason) => reason.storageValue == value,
      orElse: () => LowTreatmentReason.other,
    );
  }
}

@freezed
abstract class LowTreatmentContext with _$LowTreatmentContext {
  const factory LowTreatmentContext({
    required int mealId,
    int? relatedMealId,
    required LowTreatmentContextSource source,
    double? suggestedCarbs,
    int? suggestedWithinMinutes,
    DateTime? suggestionAt,
    DateTime? deviceStatusDate,
    required LowTreatmentReason reason,
    @Default(false) bool isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _LowTreatmentContext;
}
