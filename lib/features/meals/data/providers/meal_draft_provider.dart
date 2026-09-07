import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/nutrition/confidence_level.dart';
import '../../../../core/logger/logger.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../drafts/meal_draft.dart';
import '../model/copied_meal_type.dart';
import '../models/meal_ingredient_replacement_result.dart';

part 'meal_draft_provider.g.dart';

@riverpod
class MealIngredientAmountDraftNotifier
    extends _$MealIngredientAmountDraftNotifier {
  @override
  double build() {
    return 0;
  }

  void setAmount(String amount) => state = double.tryParse(amount) ?? 0;
  void setValue(double amount) => state = amount < 0 ? 0 : amount;
  String getAmount() => state.toString();
}

@riverpod
class MealIngredientConfidenceDraftNotifier
    extends _$MealIngredientConfidenceDraftNotifier {
  @override
  ConfidenceLevel build() {
    return ConfidenceLevel.medium;
  }

  ConfidenceLevel getConfidence() => state;
  void setConfidence(ConfidenceLevel confidence) => state = confidence;
}

@riverpod
class MealIngredientsDraftNotifier extends _$MealIngredientsDraftNotifier {
  @override
  MealIngredientsDraft build() {
    return MealIngredientsDraft(
      ingredient: IngredientDraft.draft(
        name: '',
        carbsPer100g: 0,
        fatPer100g: 0,
        fiberPer100g: 0,
        proteinPer100g: 0,
        nutritionConfidence: 0.25,
        isReference: false,
      ),
      ingredientPortion: IngredientPortionDraft(
        portion: PortionSelection.draft(name: '', unitHint: ''),
        amount: 0,
      ),
      amount: 0,
      quantityConfidence: 0.50,
      entryType: 'planned',
      consumedAmount: 0,
      consumedConfidence: 0,
    );
  }

  void overrideMealIngredient(MealIngredientsDraft mealIngredient) =>
      state = mealIngredient;

  void setIngredient(IngredientDraft ingredient) =>
      state = state.copyWith(ingredient: ingredient);
  void setIngredientPortion(PortionSelection portion) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(portion: portion),
  );
  void selectIngredientPortion(PortionSelection portion) {
    if (state.ingredientPortion.portion == portion) return;
    state = state.copyWith(
      ingredientPortion: state.ingredientPortion.copyWith(
        portion: portion,
        amount: 0,
      ),
    );
  }

  void setIngredientPortionAmount(double amount) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(amount: amount),
  );
  void applyAmountForm({
    required double amount,
    required ConfidenceLevel confidence,
  }) {
    // Preserve the original precision when the slider level has not changed.
    final quantityConfidence =
        ConfidenceLevelX.fromDouble01(state.quantityConfidence) == confidence
        ? state.quantityConfidence
        : confidence.toDouble01();
    state = state.copyWith(
      amount: amount,
      quantityConfidence: quantityConfidence,
    );
  }

  void setQuantityConfidence(ConfidenceLevel confidence) =>
      state = state.copyWith(quantityConfidence: confidence.toDouble01());
}

@riverpod
class MealDraftNotifier extends _$MealDraftNotifier with Logging {
  @override
  MealDraft build() {
    return _emptyDraft();
  }

  MealDraft _emptyDraft() {
    return MealDraft(
      name: '',
      mealIngredients: [],
      plannedAt: clock.now(),
      status: 'planned',
    );
  }

  void reset() => state = _emptyDraft();
  void setName(String name) => state = state.copyWith(name: name);
  void setPlannedAt(DateTime plannedAt) {
    logI("Srtting planned at to ${plannedAt.toIso8601String()}");
    state = state.copyWith(plannedAt: plannedAt);
  }

  void setBasedOnMealId(int? basedOnMealId) =>
      state = state.copyWith(basedOnMealId: basedOnMealId);
  void setMealTemplateId(int? mealTemplateId) =>
      state = state.copyWith(mealTemplateId: mealTemplateId);
  void setStatus(String status) => state = state.copyWith(status: status);
  void removeMealIngredient(MealIngredientsDraft mealIngredient) {
    final ingredients = [...state.mealIngredients];
    final index = ingredients.indexOf(mealIngredient);
    if (index < 0) {
      return;
    }

    ingredients.removeAt(index);
    state = state.copyWith(mealIngredients: ingredients);
  }

  bool addMealIngredient(MealIngredientsDraft mealIngredient) {
    if (state.mealIngredients.any(
      (ingredient) => ingredient.isSameIngredientAs(mealIngredient),
    )) {
      return false;
    }

    state = state.copyWith(
      mealIngredients: [...state.mealIngredients, mealIngredient],
    );
    return true;
  }

  MealIngredientReplacementResult replaceMealIngredient(
    MealIngredientsDraft original,
    MealIngredientsDraft replacement,
  ) {
    final ingredients = [...state.mealIngredients];
    final index = ingredients.indexOf(original);
    if (index < 0) {
      return MealIngredientReplacementResult.notFound;
    }

    for (var otherIndex = 0; otherIndex < ingredients.length; otherIndex++) {
      if (otherIndex != index &&
          ingredients[otherIndex].isSameIngredientAs(replacement)) {
        return MealIngredientReplacementResult.duplicate;
      }
    }

    ingredients[index] = replacement;
    state = state.copyWith(mealIngredients: ingredients);
    return MealIngredientReplacementResult.replaced;
  }

  void addMealIngredients(List<MealIngredientsDraft> mealIngredients) =>
      state = state.copyWith(
        mealIngredients: [...state.mealIngredients, ...mealIngredients],
      );
  void clearMealIngredients() => state = state.copyWith(mealIngredients: []);
  void setMealIngredients(List<MealIngredientsDraft> mealIngredients) =>
      state = state.copyWith(mealIngredients: mealIngredients);

  void applySource(
    CopiedMealType source,
    List<MealIngredientsDraft> ingredients,
  ) {
    state = switch (source) {
      CopiedMealFromTemplate() => state.copyWith(
        name: source.name,
        mealIngredients: ingredients,
        mealTemplateId: source.id,
        basedOnMealId: source.copiedFromMealId,
      ),
      CopiedMealFromMeal() => state.copyWith(
        mealIngredients: ingredients,
        mealTemplateId: source.copiedFromTemplateId,
        basedOnMealId: source.copiedFromMealId ?? source.id,
      ),
    };
  }
}

extension MealIngredientsDraftIdentity on MealIngredientsDraft {
  bool isSameIngredientAs(MealIngredientsDraft other) {
    final ingredientId = ingredient.getIngredientIdOrNull();
    final otherIngredientId = other.ingredient.getIngredientIdOrNull();
    if (ingredientId != null && otherIngredientId != null) {
      return ingredientId == otherIngredientId;
    }

    if (ingredient == other.ingredient) {
      return true;
    }

    final barcode = ingredient.barcode?.trim();
    final otherBarcode = other.ingredient.barcode?.trim();
    if (barcode != null &&
        barcode.isNotEmpty &&
        otherBarcode != null &&
        otherBarcode.isNotEmpty) {
      return barcode == otherBarcode;
    }

    return false;
  }
}
