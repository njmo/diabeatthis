import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/drafts/portion_filter.dart';
import '../../../portions/data/providers/portion_provider.dart';
import 'meal_draft_provider.dart';

part 'add_ingredients_provider.g.dart';

enum AddMealIngredientStage {
  ingredientSearch,
  ingredientForm,
  portionAddNewSearch,
  portionAddNewForm,
  portionSpecifyAmount,
  definedPortionsSearch,
  amountForm,
  summary,
}

@riverpod
GlobalKey<FormState> mealIngredientFormKey(Ref ref) {
  return GlobalKey<FormState>();
}

@riverpod
class AddMealIngredientStageNotifier extends _$AddMealIngredientStageNotifier {
  late AddMealIngredientStage prev;
  @override
  AddMealIngredientStage build() {
    prev = AddMealIngredientStage.ingredientSearch;
    return AddMealIngredientStage.ingredientSearch;
  }

  void setOverride() {
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
    state = AddMealIngredientStage.amountForm;
  }

  void setStage(AddMealIngredientStage stage) => state = stage;
  void nextStage() async {
    prev = state;
    switch (state) {
      case AddMealIngredientStage.ingredientSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        if (ingredientDraft.isReference) {
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
          state = AddMealIngredientStage.amountForm;
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(
            PortionFilter.byQueryForIngredient(
              ingredientId: ingredientDraft.map(
                draft: (draft) => 0,
                existing: (existing) => existing.id,
              ),
            ),
          );

          state = AddMealIngredientStage.definedPortionsSearch;
        }
        break;
      case AddMealIngredientStage.ingredientForm:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        if (ingredientDraft.isReference) {
          state = AddMealIngredientStage.amountForm;
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(PortionFilter.byQuery());

          state = AddMealIngredientStage.portionAddNewSearch;
        }
        break;
      case AddMealIngredientStage.portionAddNewSearch:
      case AddMealIngredientStage.portionAddNewForm:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        state = AddMealIngredientStage.portionSpecifyAmount;
        break;
      case AddMealIngredientStage.portionSpecifyAmount:
        final ingredientAmountInPortion = ref.read(
          ingredientPortionAmountDraftProvider,
        );
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortionAmount(
          ingredientAmountInPortion,
        );
        state = AddMealIngredientStage.amountForm;
        break;
      case AddMealIngredientStage.definedPortionsSearch:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        state = AddMealIngredientStage.amountForm;
        break;
      case AddMealIngredientStage.amountForm:
        final amountDraft = ref.read(mealIngredientAmountDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setAmount(amountDraft);
        state = AddMealIngredientStage.summary;
        break;
      case AddMealIngredientStage.summary:
        throw UnimplementedError();
    }
  }

  void toOppositeStage() {
    prev = state;
    switch (state) {
      case AddMealIngredientStage.ingredientSearch:
        state = AddMealIngredientStage.ingredientForm;
        ref.invalidate(ingredientDraftProvider);
        break;
      case AddMealIngredientStage.definedPortionsSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final portionsFilter = ref.read(portionFilterProvider.notifier);
        portionsFilter.setFilter(
          PortionFilter.allUnassignedForIngredient(
            ingredientId: ingredientDraft.map(
              draft: (draft) => 0,
              existing: (existing) => existing.id,
            ),
          ),
        );
        state = AddMealIngredientStage.portionAddNewSearch;
        break;
      case AddMealIngredientStage.portionAddNewForm:
        state = AddMealIngredientStage.portionAddNewSearch;
        ref.invalidate(portionDraftProvider);
        break;
      case AddMealIngredientStage.ingredientForm:
        state = AddMealIngredientStage.ingredientSearch;
        break;
      case AddMealIngredientStage.portionAddNewSearch:
        ref.invalidate(portionDraftProvider);
        state = AddMealIngredientStage.portionAddNewForm;
        break;
      case AddMealIngredientStage.amountForm:
      case AddMealIngredientStage.summary:
      case AddMealIngredientStage.portionSpecifyAmount:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  bool validateStage() {
    return false;
  }

  void back() {
    state = prev;
  }
}
