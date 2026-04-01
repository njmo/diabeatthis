import '../../../meals/data/drafts/meal_draft.dart';
import 'meal_summary_item_draft.dart';

class MealSummaryDraft {
  final int mealId;

  final List<int> itemIds;
  final Map<int, MealSummaryItemDraft> itemsById;

  final List<MealIngredientsDraft> extraItems;

  const MealSummaryDraft({
    required this.mealId,
    required this.itemIds,
    required this.itemsById,
    required this.extraItems,
  });

  MealSummaryDraft copyWith({
    int? mealId,
    List<int>? itemIds,
    Map<int, MealSummaryItemDraft>? itemsById,
    List<MealIngredientsDraft>? extraItems,
  }) {
    return MealSummaryDraft(
      mealId: mealId ?? this.mealId,
      itemIds: itemIds ?? this.itemIds,
      itemsById: itemsById ?? this.itemsById,
      extraItems: extraItems ?? this.extraItems,
    );
  }
}
