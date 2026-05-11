import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../meals/data/drafts/meal_draft.dart';
import '../../domain/use_cases/finalize_meal_summary_use_case.dart';
import '../../domain/use_cases/load_meal_summary_data_use_case.dart';
import '../models/meal_summary_draft.dart';
import '../models/meal_summary_item_draft.dart';
import '../utils/meal_summary_formatters.dart';

part 'meal_summary_controller.g.dart';

@riverpod
class MealSummaryControllerNotifier extends _$MealSummaryControllerNotifier {
  @override
  Future<MealSummaryDraft> build(int mealId) async {
    final useCase = ref.read(loadMealSummaryDataUseCaseProvider);
    final data = await useCase.call(mealId);

    final itemIds = <int>[];
    final itemsById = <int, MealSummaryItemDraft>{};

    for (final item in data.items) {
      itemIds.add(item.id);
      itemsById[item.id] = MealSummaryItemDraft(
        name: item.name,
        mealIngredientId: item.id,
        plannedAmount: item.plannedAmount,
        amountLabel: mealSummaryAmountLabel(item),
        netCarbsPerAmount: item.netCarbsPerAmount,
        consumedAmount: item.consumedAmount,
        consumedConfidence: item.consumedConfidence,
      );
    }

    return MealSummaryDraft(
      mealId: mealId,
      itemIds: itemIds,
      itemsById: itemsById,
      extraItems: [],
    );
  }

  void setConsumedAmount(int mealIngredientId, double value) {
    final current = state.value;
    if (current == null) return;

    final item = current.itemsById[mealIngredientId];
    if (item == null) return;

    state = AsyncData(
      current.copyWith(
        itemsById: {
          ...current.itemsById,
          mealIngredientId: item.copyWith(
            consumedAmount: value < 0 ? 0 : value,
          ),
        },
      ),
    );
  }

  Future<void> saveSummary({
    MealSummarySaveMode mode = MealSummarySaveMode.finishMeal,
  }) async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncLoading();

    try {
      final useCase = ref.read(finalizeMealSummaryUseCaseProvider);
      await useCase.call(current, mode: mode);
      state = AsyncData(current);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void setConsumedConfidence(int mealIngredientId, double value) {
    final current = state.value;
    if (current == null) return;

    final item = current.itemsById[mealIngredientId];
    if (item == null) return;

    state = AsyncData(
      current.copyWith(
        itemsById: {
          ...current.itemsById,
          mealIngredientId: item.copyWith(consumedConfidence: value),
        },
      ),
    );
  }

  void addExtraItem(MealIngredientsDraft item) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(extraItems: [...current.extraItems, item]),
    );
  }

  void removeExtraItem(MealIngredientsDraft item) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        extraItems: current.extraItems.where((e) => e != item).toList(),
      ),
    );
  }

  void replaceExtraItem(
    MealIngredientsDraft oldItem,
    MealIngredientsDraft newItem,
  ) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        extraItems: [
          for (final item in current.extraItems)
            if (item == oldItem) newItem else item,
        ],
      ),
    );
  }
}
