
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';


part 'meal_draft.freezed.dart';

@freezed
abstract class MealIngredientsDraft with _$MealIngredientsDraft
{
  const factory MealIngredientsDraft( {
    required IngredientSelection ingredient,
    required IngredientPortionDraft ingredientPortion,
    required int amount,
  }) = _MealIngredientsDraft;
}

@freezed
abstract class MealDraft with _$MealDraft
{
  const factory MealDraft({
  required String name,
  required int carbs,
  required int glucose,
  required double insulin,
  required List<MealIngredientsDraft> mealIngredients,
  required DateTime createdAt,
  required DateTime plannedAt,
  required String status,
  }) = _MealDraft;
}