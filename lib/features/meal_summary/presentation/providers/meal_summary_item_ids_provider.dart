import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../controllers/meal_summary_controller.dart';

part 'meal_summary_item_ids_provider.g.dart';

@riverpod
List<int> mealSummaryItemIds(Ref ref, int mealId) {
  return ref.watch(
    mealSummaryControllerProvider(
      mealId,
    ).select((asyncDraft) => asyncDraft.value?.itemIds ?? const []),
  );
}
