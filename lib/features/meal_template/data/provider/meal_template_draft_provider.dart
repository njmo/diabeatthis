import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../drafts/template_meal_draft.dart';

part 'meal_template_draft_provider.g.dart';

@riverpod
class MealTemplateIngredientAmountDraftNotifier
    extends _$MealTemplateIngredientAmountDraftNotifier {
  @override
  double build() {
    return 0;
  }

  void setAmount(String amount) => state = double.tryParse(amount) ?? 0;
  String getAmount() => state.toString();
}

@riverpod
class MealTemplateIngredientConfidenceDraftNotifier
    extends _$MealTemplateIngredientConfidenceDraftNotifier {
  @override
  ConfidenceLevel build() {
    return ConfidenceLevel.high;
  }

  ConfidenceLevel getConfidence() => state;
  void setConfidence(ConfidenceLevel confidence) => state = confidence;
}

@riverpod
class MealTemplateIngredientsDraftNotifier
    extends _$MealTemplateIngredientsDraftNotifier {
  @override
  MealTemplateIngredientsDraft build() {
    return MealTemplateIngredientsDraft(
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
      defaultAmount: 0,
      quantityConfidence: 0,
      isOptional: false,
      prepMethod: '',
      notes: '',
    );
  }

  void setIngredient(domain.Ingredient ingredient) =>
      state = state.copyWith(ingredient: ingredient);
  void setIngredientPortion(PortionSelection portion) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(portion: portion),
  );
  void setIngredientPortionAmount(double amount) => state = state.copyWith(
    ingredientPortion: state.ingredientPortion.copyWith(amount: amount),
  );
  void setDefaultAmount(double amount) => state = state.copyWith(defaultAmount: amount);
  void setQuantityConfidence(ConfidenceLevel confidence) =>
      state = state.copyWith(quantityConfidence: confidence.toDouble01());
  void setPrepMethod(String prepMethod) => state = state.copyWith(prepMethod: prepMethod);
  void setNotes(String notes) => state = state.copyWith(notes: notes);
  void setIsOptional(bool isOptional) => state = state.copyWith(isOptional: isOptional);
}

@riverpod
class MealTemplateDraftNotifier extends _$MealTemplateDraftNotifier {
  @override
  MealTemplateDraft build() {
    return MealTemplateDraft(
      name: '',
      mealIngredients: [],
      notes: '',
      isFavorite: false,
    );
  }

  void setName(String name) => state = state.copyWith(name: name);

  void removeMealTemplateIngredient(MealTemplateIngredientsDraft mealIngredient) =>
      state = state.copyWith(
        mealIngredients: state.mealIngredients
            .where((element) => element != mealIngredient)
            .toList(),
      );
  void addMealTemplateIngredient(MealTemplateIngredientsDraft mealIngredient) => state = state
      .copyWith(mealIngredients: [...state.mealIngredients, mealIngredient]);
  void addMealTemplateIngredients(List<MealTemplateIngredientsDraft> mealIngredients) =>
      state = state.copyWith(
        mealIngredients: [...state.mealIngredients, ...mealIngredients],
      );
  void setNotes(String notes) => state = state.copyWith(notes: notes);
  void setIsFavorite(bool isFavorite) => state = state.copyWith(isFavorite: isFavorite);
  void setCreatedFromMealId(int createdFromMealId) => state = state.copyWith(createdFromMealId: createdFromMealId);
}
