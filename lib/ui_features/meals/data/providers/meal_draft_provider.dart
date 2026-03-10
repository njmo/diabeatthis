import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../presentation/widgets/confidence_slider.dart';
import '../drafts/meal_draft.dart';

part 'meal_draft_provider.g.dart';

@riverpod
class MealIngredientAmountDraftNotifier
    extends _$MealIngredientAmountDraftNotifier {
  @override
  int build() {
    return 0;
  }

  void setAmount(String amount) => state = int.tryParse(amount) ?? 0;
  String getAmount() => state.toString();
}

@riverpod
class MealIngredientConfidenceDraftNotifier
    extends _$MealIngredientConfidenceDraftNotifier {
  @override
  ConfidenceLevel build() {
    return ConfidenceLevel.high;
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
        nutritionConfidence: 0,
        isReference: false,
      ),
      ingredientPortion: IngredientPortionDraft(
        portion: PortionSelection.draft(name: '', unitHint: ''),
        amount: 0,
      ),
      amount: 0,
      quantityConfidence: 0,
    );
  }

  void setIngredient(domain.Ingredient ingredient) =>
      state = state.copyWith(ingredient: ingredient);
  void setIngredientPortion(PortionSelection portion) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(portion: portion),
  );
  void setIngredientPortionAmount(int amount) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(amount: amount),
  );
  void setAmount(int amount) => state = state.copyWith(amount: amount);
  void setQuantityConfidence(ConfidenceLevel confidence) =>
      state = state.copyWith(quantityConfidence: confidence.toDouble01());
}

@riverpod
class MealDraftNotifier extends _$MealDraftNotifier {
  @override
  MealDraft build() {
    return MealDraft(
      name: '',
      carbs: 0,
      glucose: 0,
      insulin: 0,
      mealIngredients: [],
      createdAt: DateTime.now(),
      plannedAt: DateTime.now(),
      status: 'draft',
    );
  }

  void setName(String name) => state = state.copyWith(name: name);
  void setCarbs(int carbs) => state = state.copyWith(carbs: carbs);
  void setGlucose(int glucose) => state = state.copyWith(glucose: glucose);
  void setInsulin(double insulin) => state = state.copyWith(insulin: insulin);
  void setCreatedAt(DateTime createdAt) =>
      state = state.copyWith(createdAt: createdAt);
  void setPlannedAt(DateTime plannedAt) =>
      state = state.copyWith(plannedAt: plannedAt);
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
}
