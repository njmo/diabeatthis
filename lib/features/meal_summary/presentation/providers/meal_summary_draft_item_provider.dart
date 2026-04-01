import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../controllers/meal_summary_controller.dart';
import '../models/meal_summary_item_draft.dart';

part 'meal_summary_draft_item_provider.g.dart';

@riverpod
MealSummaryItemDraft? mealSummaryItemDraft(
  Ref ref,
  int mealId,
  int mealIngredientId,
) {
  return ref.watch(
    mealSummaryControllerProvider(
      mealId,
    ).select((asyncDraft) => asyncDraft.value?.itemsById[mealIngredientId]),
  );
}
