import '../../../meals/common/models/meal_wizard_assignment.dart';

enum MealEatingTimeSource {
  recordedStage,
  summaryTimestamp,
  plannedFallback,
  unknown,
}

/// Confidence describes the saved food estimate, not clinical certainty or an AI score.
class MealNutritionConfidence {
  final double? carbsQuantity;
  final double? carbsNutrition;
  final double? carbsEffective;
  final double? fatProteinQuantity;
  final double? fatProteinNutrition;
  final double? fatProteinEffective;
  const MealNutritionConfidence({
    this.carbsQuantity,
    this.carbsNutrition,
    this.carbsEffective,
    this.fatProteinQuantity,
    this.fatProteinNutrition,
    this.fatProteinEffective,
  });
}

class MealRecordEvidence {
  final MealEatingTimeSource eatingTimeSource;
  final MealNutritionConfidence? nutritionConfidence;

  /// Null: relation source unavailable/not loaded; empty: read successfully, no links.
  final List<MealWizardAssignment>? wizardAssignments;
  const MealRecordEvidence.unknown()
    : eatingTimeSource = MealEatingTimeSource.unknown,
      nutritionConfidence = null,
      wizardAssignments = null;
  MealRecordEvidence({
    required this.eatingTimeSource,
    required this.nutritionConfidence,
    required List<MealWizardAssignment>? wizardAssignments,
  }) : wizardAssignments = wizardAssignments == null
           ? null
           : List.unmodifiable(wizardAssignments);
}
