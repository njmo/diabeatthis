import '../../../../core/domain/model/low_treatment_context.dart';

/// A saved consumption entry, distinct from an unaccepted AAPS suggestion.
class RecordedLowTreatment {
  final int mealId;
  final DateTime eatenAt;
  final double? netCarbsGrams;
  final LowTreatmentReason? reason;
  final LowTreatmentContextSource? source;
  final int? relatedMealId;
  final int? relatedActivityLogId;
  final double? suggestedCarbs;

  const RecordedLowTreatment({
    required this.mealId,
    required this.eatenAt,
    required this.netCarbsGrams,
    this.reason,
    this.source,
    this.relatedMealId,
    this.relatedActivityLogId,
    this.suggestedCarbs,
  });
}
