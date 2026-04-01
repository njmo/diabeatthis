import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../meals/data/drafts/meal_draft.dart';
import '../controllers/meal_summary_controller.dart';

part 'meal_summary_extra_items_provider.g.dart';

@riverpod
List<MealIngredientsDraft> mealSummaryExtraItems(Ref ref, int mealId) {
  return ref.watch(
    mealSummaryControllerProvider(
      mealId,
    ).select((asyncDraft) => asyncDraft.value?.extraItems ?? const []),
  );
}
