import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../drafts/template_meal_draft.dart';

part 'meal_template_draft_provider.g.dart';

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

  void removeMealTemplateIngredient(
    MealTemplateIngredientsDraft mealIngredient,
  ) => state = state.copyWith(
    mealIngredients: state.mealIngredients
        .where((element) => element != mealIngredient)
        .toList(),
  );
  void addMealTemplateIngredient(MealTemplateIngredientsDraft mealIngredient) =>
      state = state.copyWith(
        mealIngredients: [...state.mealIngredients, mealIngredient],
      );
  void addMealTemplateIngredients(
    List<MealTemplateIngredientsDraft> mealIngredients,
  ) => state = state.copyWith(
    mealIngredients: [...state.mealIngredients, ...mealIngredients],
  );
  void setNotes(String notes) => state = state.copyWith(notes: notes);
  void setIsFavorite(bool isFavorite) =>
      state = state.copyWith(isFavorite: isFavorite);
  void setCreatedFromMealId(int createdFromMealId) =>
      state = state.copyWith(createdFromMealId: createdFromMealId);
}
