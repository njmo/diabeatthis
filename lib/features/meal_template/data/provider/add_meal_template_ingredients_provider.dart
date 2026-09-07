import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/navigation/step_history.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/drafts/portion_filter.dart';
import '../../../portions/data/providers/portion_provider.dart';
import 'meal_template_draft_provider.dart';

part 'add_meal_template_ingredients_provider.g.dart';

enum AddMealTemplateIngredientStage {
  dismiss,
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
  final _history = StepHistory(root: AddMealTemplateIngredientStage.dismiss);

  @override
  AddMealTemplateIngredientStage build() {
    _history.reset();
    return AddMealTemplateIngredientStage.ingredientSearch;
  }

  void modifyIngredientStage(bool isReference) {
    _history.reset();
    if (isReference) {
      state = AddMealTemplateIngredientStage.amountForm;
      return;
    }

    final ingredientDraft = ref
        .read(mealTemplateIngredientsDraftProvider)
        .ingredient;
    final ingredientId = ingredientDraft.getIngredientIdOrNull();
    final filter = ingredientId == null
        ? PortionFilter.byQuery()
        : PortionFilter.byQueryForIngredient(ingredientId: ingredientId);
    ref.watch(portionFilterProvider.notifier).setFilter(filter);
    if (ingredientId == null) {
      state = AddMealTemplateIngredientStage.portionAddNewSearch;
      return;
    }

    state = AddMealTemplateIngredientStage.definedPortionsSearch;
  }

  void setOverride() {
    final mealIngredientsDraft = ref.watch(
      mealTemplateIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
    _moveTo(AddMealTemplateIngredientStage.amountForm);
  }

  void setStage(AddMealTemplateIngredientStage stage) => _moveTo(stage);
  void nextStage() async {
    switch (state) {
      case AddMealTemplateIngredientStage.dismiss:
        throw UnimplementedError();
      case AddMealTemplateIngredientStage.ingredientSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        if (ingredientDraft.isReference) {
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
          _moveTo(AddMealTemplateIngredientStage.amountForm);
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(
            PortionFilter.byQueryForIngredient(
              ingredientId: ingredientDraft.toDomain().id,
            ),
          );

          _moveTo(AddMealTemplateIngredientStage.definedPortionsSearch);
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
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
          _moveTo(AddMealTemplateIngredientStage.amountForm);
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(PortionFilter.byQuery());

          _moveTo(AddMealTemplateIngredientStage.portionAddNewSearch);
        }
        break;
      case AddMealTemplateIngredientStage.portionAddNewSearch:
      case AddMealTemplateIngredientStage.portionAddNewForm:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        _moveTo(AddMealTemplateIngredientStage.portionSpecifyAmount);
        break;
      case AddMealTemplateIngredientStage.portionSpecifyAmount:
        _moveTo(AddMealTemplateIngredientStage.amountForm);
        break;
      case AddMealTemplateIngredientStage.definedPortionsSearch:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        _moveTo(AddMealTemplateIngredientStage.amountForm);
        break;
      case AddMealTemplateIngredientStage.amountForm:
        final amountDraft = ref.read(mealTemplateIngredientAmountDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealTemplateIngredientsDraftProvider.notifier,
        );
        final confidence = ref.read(mealIngredientConfidenceDraftProvider);
        mealIngredientsDraft.setQuantityConfidence(confidence);
        mealIngredientsDraft.setDefaultAmount(amountDraft);
        _moveTo(AddMealTemplateIngredientStage.summary);
        break;
      case AddMealTemplateIngredientStage.summary:
        throw UnimplementedError();
    }
  }

  void toOppositeStage() {
    switch (state) {
      case AddMealTemplateIngredientStage.dismiss:
        throw UnimplementedError();
      case AddMealTemplateIngredientStage.ingredientSearch:
        ref.invalidate(ingredientDraftProvider);
        _moveTo(AddMealTemplateIngredientStage.ingredientForm);
        break;
      case AddMealTemplateIngredientStage.definedPortionsSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final portionsFilter = ref.read(portionFilterProvider.notifier);
        portionsFilter.setFilter(
          PortionFilter.allUnassignedForIngredient(
            ingredientId: ingredientDraft.toDomain().id,
          ),
        );
        _moveTo(AddMealTemplateIngredientStage.portionAddNewSearch);
        break;
      case AddMealTemplateIngredientStage.portionAddNewForm:
        ref.invalidate(portionDraftProvider);
        _moveTo(AddMealTemplateIngredientStage.portionAddNewSearch);
        break;
      case AddMealTemplateIngredientStage.ingredientForm:
        _moveTo(AddMealTemplateIngredientStage.ingredientSearch);
        break;
      case AddMealTemplateIngredientStage.portionAddNewSearch:
        ref.invalidate(portionDraftProvider);
        _moveTo(AddMealTemplateIngredientStage.portionAddNewForm);
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
    state = _history.pop();
  }

  void _moveTo(AddMealTemplateIngredientStage next) {
    _history.push(state);
    state = next;
  }
}
