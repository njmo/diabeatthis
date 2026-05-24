import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../data/models/quick_low_treatment_items_state.dart';
import '../../data/models/quick_low_treatment_slot.dart';
import '../../domain/use_cases/delete_quick_low_treatment_item_use_case.dart';
import '../../domain/use_cases/load_quick_low_treatment_items_use_case.dart';
import '../../domain/use_cases/swap_quick_low_treatment_item_slots_use_case.dart';
import '../../domain/use_cases/upsert_quick_low_treatment_item_use_case.dart';

part 'quick_low_treatment_items_controller.g.dart';

@riverpod
class QuickLowTreatmentItemsController
    extends _$QuickLowTreatmentItemsController {
  late UpsertQuickLowTreatmentItemUseCase _upsertItemUseCase;
  late DeleteQuickLowTreatmentItemUseCase _deleteItemUseCase;
  late LoadQuickLowTreatmentItemsUseCase _loadItemsUseCase;
  late SwapQuickLowTreatmentItemSlotsUseCase _swapSlotsUseCase;

  @override
  Future<QuickLowTreatmentItemsState> build() async {
    _upsertItemUseCase = ref.watch(upsertQuickLowTreatmentItemUseCaseProvider);
    _deleteItemUseCase = ref.watch(deleteQuickLowTreatmentItemUseCaseProvider);
    _loadItemsUseCase = ref.watch(loadQuickLowTreatmentItemsUseCaseProvider);
    _swapSlotsUseCase = ref.watch(
      swapQuickLowTreatmentItemSlotsUseCaseProvider,
    );

    final items = await _loadItemsUseCase.call();
    return QuickLowTreatmentItemsState(
      slots: buildQuickLowTreatmentSlots(items),
    );
  }

  Future<void> upsertSlot({
    required int slot,
    required MealIngredientsDraft mealIngredient,
    QuickLowTreatmentItem? existingItem,
  }) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await _upsertItemUseCase.call(
        slot: slot,
        mealIngredient: mealIngredient,
        existingItem: existingItem,
      );
      await _refreshSlots();
    } catch (_) {
      state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> deleteItem(QuickLowTreatmentItem item) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await _deleteItemUseCase.call(item);
      await _refreshSlots();
    } catch (_) {
      state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> swapSlots({
    required QuickLowTreatmentSlot source,
    required QuickLowTreatmentSlot target,
  }) async {
    final current = state.requireValue;
    final optimisticSlots = current.slots
        .map((slot) {
          if (slot.slot == source.slot) {
            return slot.withItem(target.item?.copyWith(sortOrder: source.slot));
          }
          if (slot.slot == target.slot) {
            return slot.withItem(source.item?.copyWith(sortOrder: target.slot));
          }
          return slot;
        })
        .toList(growable: false);

    state = AsyncData(current.copyWith(slots: optimisticSlots, isSaving: true));
    try {
      await _swapSlotsUseCase.call(source: source, target: target);
      await _refreshSlots();
    } catch (_) {
      state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> _refreshSlots() async {
    final items = await _loadItemsUseCase.call();
    state = AsyncData(
      QuickLowTreatmentItemsState(slots: buildQuickLowTreatmentSlots(items)),
    );
  }
}
