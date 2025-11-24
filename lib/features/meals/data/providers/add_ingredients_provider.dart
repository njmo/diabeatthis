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
  ingredient_search,
  ingredient_form,
  portion_add_new_search,
  portion_add_new_form,
  portion_specify_amount,
  defined_portions_search,
  amount_form,
  summary,
  completed,
}

@riverpod
GlobalKey<FormState> mealIngredientFormKey(Ref ref)
{
  return GlobalKey<FormState>();
}

@riverpod
class AddMealIngredientStageNotifier extends _$AddMealIngredientStageNotifier {
  @override
  AddMealIngredientStage build() {
    return AddMealIngredientStage.ingredient_search;
  }

  void setOverride() {
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
    state = AddMealIngredientStage.amount_form;
  }

  void setStage(AddMealIngredientStage stage) => state = stage;
  void nextStage() async {
    switch (state) {
      case AddMealIngredientStage.ingredient_search:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        final portionsFilter = ref.read(portionFilterProvider.notifier);
        portionsFilter.setFilter(
          PortionFilter.byQueryForIngredient(
            ingredientId: ingredientDraft.map(
              draft: (draft) => 0,
              existing: (existing) => existing.id,
            ),
          ),
        );

        state = AddMealIngredientStage.defined_portions_search;
        break;
      case AddMealIngredientStage.ingredient_form:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        final portionsFilter = ref.read(portionFilterProvider.notifier);
        portionsFilter.setFilter(PortionFilter.byQuery());

        state = AddMealIngredientStage.portion_add_new_search;
        break;
      case AddMealIngredientStage.portion_add_new_search:
      case AddMealIngredientStage.portion_add_new_form:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        state = AddMealIngredientStage.portion_specify_amount;
        break;
      case AddMealIngredientStage.portion_specify_amount:
        final ingredientAmountInPortion = ref.read(
          ingredientPortionAmountDraftProvider,
        );
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortionAmount(
          ingredientAmountInPortion,
        );
        state = AddMealIngredientStage.amount_form;
        break;
      case AddMealIngredientStage.defined_portions_search:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        state = AddMealIngredientStage.amount_form;
        break;
      case AddMealIngredientStage.amount_form:
        final amountDraft = ref.read(mealIngredientAmountDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setAmount(amountDraft);
        state = AddMealIngredientStage.summary;
        break;
      case AddMealIngredientStage.summary:
        state = AddMealIngredientStage.completed;
        break;
      case AddMealIngredientStage.completed:
        throw UnimplementedError();
    }
  }

  void toOppositeStage() {
    switch (state) {
      case AddMealIngredientStage.ingredient_search:
        state = AddMealIngredientStage.ingredient_form;
        break;
      case AddMealIngredientStage.defined_portions_search:
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
        state = AddMealIngredientStage.portion_add_new_search;
        break;
      case AddMealIngredientStage.portion_add_new_form:
        state = AddMealIngredientStage.portion_add_new_search;
        break;
      case AddMealIngredientStage.ingredient_form:
        state = AddMealIngredientStage.ingredient_search;
        break;
      case AddMealIngredientStage.portion_add_new_search:
        state = AddMealIngredientStage.portion_add_new_form;
        break;
      case AddMealIngredientStage.amount_form:
      case AddMealIngredientStage.completed:
      case AddMealIngredientStage.summary:
      case AddMealIngredientStage.portion_specify_amount:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  bool validateStage()
  {
    return false;
  }
}
