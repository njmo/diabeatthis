import '../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../common/meal/meal_completion_decision.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import 'meal_summary_item_draft.dart';

class MealSummaryDraft {
  final int mealId;
  final String? mealStatus;

  final List<int> itemIds;
  final Map<int, MealSummaryItemDraft> itemsById;

  final List<MealIngredientsDraft> extraItems;
  final MealBolusCoverage? reviewedBolusCoverage;
  final MealCarbsCorrectionChoice? correctionChoice;

  const MealSummaryDraft({
    required this.mealId,
    required this.mealStatus,
    required this.itemIds,
    required this.itemsById,
    required this.extraItems,
    this.reviewedBolusCoverage,
    this.correctionChoice,
  });

  MealSummaryDraft copyWith({
    int? mealId,
    String? mealStatus,
    List<int>? itemIds,
    Map<int, MealSummaryItemDraft>? itemsById,
    List<MealIngredientsDraft>? extraItems,
    MealBolusCoverage? reviewedBolusCoverage,
    MealCarbsCorrectionChoice? correctionChoice,
  }) {
    return MealSummaryDraft(
      mealId: mealId ?? this.mealId,
      mealStatus: mealStatus ?? this.mealStatus,
      itemIds: itemIds ?? this.itemIds,
      itemsById: itemsById ?? this.itemsById,
      extraItems: extraItems ?? this.extraItems,
      reviewedBolusCoverage:
          reviewedBolusCoverage ?? this.reviewedBolusCoverage,
      correctionChoice: correctionChoice ?? this.correctionChoice,
    );
  }
}
