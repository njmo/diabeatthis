import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/drafts/portion_filter.dart';
import '../../../portions/data/providers/portion_provider.dart';
import 'meal_template_draft_provider.dart';

part 'add_meal_template_ingredients_provider.g.dart';

enum AddMealTemplateIngredientStage {
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
GlobalKey<FormState> mealTemplateIngredientFormKey(Ref ref) {
  return GlobalKey<FormState>();
}

@riverpod
class AddMealTemplateIngredientStageNotifier
    extends _$AddMealTemplateIngredientStageNotifier {
  late AddMealTemplateIngredientStage prev;
  @override
  AddMealTemplateIngredientStage build() {
    prev = AddMealTemplateIngredientStage.ingredientSearch;
    return AddMealTemplateIngredientStage.ingredientSearch;
  }

  void setOverride() {
    final mealIngredientsDraft = ref.watch(
      mealTemplateIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
    state = AddMealTemplateIngredientStage.amountForm;
  }

  void setStage(AddMealTemplateIngredientStage stage) => state = stage;
  void nextStage() async {
    prev = state;
    switch (state) {
      case AddMealTemplateIngredientStage.ingredientSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        if (ingredientDraft.isReference) {
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
          state = AddMealTemplateIngredientStage.amountForm;
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(
            PortionFilter.byQueryForIngredient(
              ingredientId: ingredientDraft.toDomain().id,
            ),
          );

          state = AddMealTemplateIngredientStage.definedPortionsSearch;
        }
        break;
      case AddMealTemplateIngredientStage.ingredientForm:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        //
        if (ingredientDraft.isReference) {
          state = AddMealTemplateIngredientStage.amountForm;
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(PortionFilter.byQuery());

          state = AddMealTemplateIngredientStage.portionAddNewSearch;
        }
        break;
      case AddMealTemplateIngredientStage.portionAddNewSearch:
      case AddMealTemplateIngredientStage.portionAddNewForm:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        state = AddMealTemplateIngredientStage.portionSpecifyAmount;
        break;
      case AddMealTemplateIngredientStage.portionSpecifyAmount:
        final ingredientAmountInPortion = ref.read(
          ingredientPortionAmountDraftProvider,
        );
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortionAmount(
          ingredientAmountInPortion,
        );
        state = AddMealTemplateIngredientStage.amountForm;
        break;
      case AddMealTemplateIngredientStage.definedPortionsSearch:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        state = AddMealTemplateIngredientStage.amountForm;
        break;
      case AddMealTemplateIngredientStage.amountForm:
        final amountDraft = ref.read(mealTemplateIngredientAmountDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        final confidence = ref.read(mealIngredientConfidenceDraftProvider);
        mealIngredientsDraft.setQuantityConfidence(confidence);
        mealIngredientsDraft.setDefaultAmount(amountDraft);
        state = AddMealTemplateIngredientStage.summary;
        break;
      case AddMealTemplateIngredientStage.summary:
        throw UnimplementedError();
    }
  }

  void toOppositeStage() {
    prev = state;
    switch (state) {
      case AddMealTemplateIngredientStage.ingredientSearch:
        state = AddMealTemplateIngredientStage.ingredientForm;
        ref.invalidate(ingredientDraftProvider);
        break;
      case AddMealTemplateIngredientStage.definedPortionsSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final portionsFilter = ref.read(portionFilterProvider.notifier);
        portionsFilter.setFilter(
          PortionFilter.allUnassignedForIngredient(
            ingredientId: ingredientDraft.toDomain().id,
          ),
        );
        state = AddMealTemplateIngredientStage.portionAddNewSearch;
        break;
      case AddMealTemplateIngredientStage.portionAddNewForm:
        state = AddMealTemplateIngredientStage.portionAddNewSearch;
        ref.invalidate(portionDraftProvider);
        break;
      case AddMealTemplateIngredientStage.ingredientForm:
        state = AddMealTemplateIngredientStage.ingredientSearch;
        break;
      case AddMealTemplateIngredientStage.portionAddNewSearch:
        ref.invalidate(portionDraftProvider);
        state = AddMealTemplateIngredientStage.portionAddNewForm;
        break;
      case AddMealTemplateIngredientStage.amountForm:
      case AddMealTemplateIngredientStage.summary:
      case AddMealTemplateIngredientStage.portionSpecifyAmount:
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
