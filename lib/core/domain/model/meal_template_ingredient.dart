import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'ingredient.dart';
import 'meal_template.dart';

part 'meal_template_ingredient.freezed.dart';


@Freezed(unionKey: 'kind')
abstract class MealTemplateIngredient with _$MealTemplateIngredient {
  const factory MealTemplateIngredient.existing({
    required int mealTemplateId,
    required int ingredientId,
    required int defaultAmount,
    required bool isSynced,
    required double quantityConfidence,
    bool? isOptional,
    int? portionId,
    String? prepMethod,
    String? notes,
  }) = _MealTemplateIngredientExisting;

  const factory MealTemplateIngredient.draft({
    required IngredientPortionDraft ingredientPortion,
    required int mealTemplateId,
    required int ingredientId,
    required int defaultAmount,
    required bool isSynced,
    required double quantityConfidence,
    bool? isOptional,
    String? prepMethod,
    String? notes,
  }) = _MealTemplateIngredientDraft;


  const factory MealTemplateIngredient.view({
    required MealTemplate mealTemplate,
    required Ingredient mealIngredient,
    required IngredientPortionDraft ingredientPortion,
    required int defaultAmount,
    required bool isSynced,
    required double quantityConfidence,
    bool? isOptional,
    String? prepMethod,
    String? notes,
  }) = _MealTemplateIngredientView;

  const factory MealTemplateIngredient.empty() = _MealTemplateIngredientEmpty;
}
