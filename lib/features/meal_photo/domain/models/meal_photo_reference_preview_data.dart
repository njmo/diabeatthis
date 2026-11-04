import '../../../../common/meal/meal_extended_carbs.dart';
import '../../../../common/nutrition/stable_macro_ceil.dart';
import '../../../../core/domain/model/meal_macro_summary.dart';
import 'meal_photo_nutrition.dart';
import 'meal_photo_proposal.dart';

class MealPhotoReferencePreviewData {
  const MealPhotoReferencePreviewData({
    required this.name,
    required this.netCarbsGrams,
    required this.extendedCarbsGrams,
  });
  factory MealPhotoReferencePreviewData.fromProposal(
    MealPhotoProposal proposal, {
    MealPhotoNutrition? referenceNutrition,
  }) {
    final facts = referenceNutrition ?? proposal.reference.referenceNutrition;
    if (facts == null) {
      throw StateError('Whole plate proposal requires nutrition');
    }
    final totals = MealMacroSummary(
      carbsGrams: facts.carbs,
      fatGrams: facts.fat,
      proteinGrams: facts.protein,
      fiberGrams: facts.fiber,
      totalGrams: proposal.reference.estimatedWeightGrams ?? 0,
      netCarbsGrams: facts.netCarbs,
    );
    return MealPhotoReferencePreviewData(
      name: proposal.name,
      netCarbsGrams: facts.netCarbs.ceilMacro(),
      extendedCarbsGrams: mealExtendedCarbsFromMacros(totals),
    );
  }
  final String name;
  final int netCarbsGrams;
  final int extendedCarbsGrams;
}
