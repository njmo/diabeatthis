import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/domain/use_cases/load_ingredient_details_use_case.dart';
import '../../data/domain/use_cases/update_ingredient_details_use_case.dart';
import '../../data/mappers/ingredient_details_mapper.dart';
import '../../data/models/ingredient_details_data.dart';
import '../../data/providers/ingredient_provider.dart';
import '../models/ingredient_page_state.dart';

part 'ingredient_details_controller.g.dart';

@riverpod
class IngredientDetailsControllerNotifier
    extends _$IngredientDetailsControllerNotifier {
  @override
  Future<IngredientPageState> build(int ingredientId) async {
    final useCase = ref.read(loadIngredientDetailsUseCaseProvider);
    final data = await useCase.call(ingredientId);

    return IngredientPageState(data: data);
  }

  void startEditing() {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }

    ref
        .read(ingredientDraftProvider.notifier)
        .overrideDraft(current.data.ingredient.toDraft());
    ref.invalidate(mealIngredientFormKeyProvider);
    state = AsyncData(current.copyWith(isEditing: true));
  }

  void cancelEditing() {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }

    state = AsyncData(current.copyWith(isEditing: false));
  }

  Future<void> save() async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));

    try {
      final ingredient = ref.read(ingredientDraftProvider);
      final updateUseCase = ref.read(updateIngredientDetailsUseCaseProvider);
      await updateUseCase.call(ingredient);

      final loadUseCase = ref.read(loadIngredientDetailsUseCaseProvider);
      final data = await loadUseCase.call(ingredientId);
      state = AsyncData(IngredientPageState(data: data));
    } catch (_) {
      state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> updatePortionAmount({
    required int portionId,
    required double gramsPerPortion,
  }) async {
    final current = state.requireValue;
    if (current.isSaving) {
      return;
    }

    state = AsyncData(current.copyWith(isSaving: true));

    try {
      final updateUseCase = ref.read(updateIngredientDetailsUseCaseProvider);
      await updateUseCase.updatePortionAmount(
        ingredientId: ingredientId,
        portionId: portionId,
        gramsPerPortion: gramsPerPortion,
      );

      state = AsyncData(
        current.copyWith(
          data: _updatedPortionData(
            current.data,
            portionId: portionId,
            gramsPerPortion: gramsPerPortion,
          ),
          isSaving: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  IngredientDetailsData _updatedPortionData(
    IngredientDetailsData data, {
    required int portionId,
    required double gramsPerPortion,
  }) {
    return data.copyWith(
      portions: [
        for (final portion in data.portions)
          if (portion.portionId == portionId)
            portion.copyWith(gramsPerPortion: gramsPerPortion)
          else
            portion,
      ],
    );
  }
}
