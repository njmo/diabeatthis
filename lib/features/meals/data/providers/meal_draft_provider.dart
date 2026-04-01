import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/logger/logger.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../presentation/widgets/confidence_slider.dart';
import '../drafts/meal_draft.dart';

part 'meal_draft_provider.g.dart';

@riverpod
class MealIngredientAmountDraftNotifier
    extends _$MealIngredientAmountDraftNotifier {
  @override
  double build() {
    return 0;
  }

  void setAmount(String amount) => state = double.tryParse(amount) ?? 0;
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
      ingredient: domain.Ingredient.draft(
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

  void setIngredient(domain.Ingredient ingredient) =>
      state = state.copyWith(ingredient: ingredient);
  void setIngredientPortion(PortionSelection portion) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(portion: portion),
  );
  void setIngredientPortionAmount(double amount) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(amount: amount),
  );
  void setAmount(double amount) => state = state.copyWith(amount: amount);
  void setQuantityConfidence(ConfidenceLevel confidence) =>
      state = state.copyWith(quantityConfidence: confidence.toDouble01());
}

@riverpod
class MealDraftNotifier extends _$MealDraftNotifier with Logging {
  @override
  MealDraft build() {
    return MealDraft(
      name: '',
      mealIngredients: [],
      plannedAt: clock.now(),
      status: 'draft',
    );
  }

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
  void removeMealIngredient(MealIngredientsDraft mealIngredient) =>
      state = state.copyWith(
        mealIngredients: state.mealIngredients
            .where((element) => element != mealIngredient)
            .toList(),
      );
  void addMealIngredient(MealIngredientsDraft mealIngredient) => state = state
      .copyWith(mealIngredients: [...state.mealIngredients, mealIngredient]);
  void addMealIngredients(List<MealIngredientsDraft> mealIngredients) =>
      state = state.copyWith(
        mealIngredients: [...state.mealIngredients, ...mealIngredients],
      );
  void clearMealIngredients() => state = state.copyWith(mealIngredients: []);
  void setMealIngredients(List<MealIngredientsDraft> mealIngredients) =>
      state = state.copyWith(mealIngredients: mealIngredients);
}
