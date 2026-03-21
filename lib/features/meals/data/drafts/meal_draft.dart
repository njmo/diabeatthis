import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';

part 'meal_draft.freezed.dart';

@freezed
abstract class MealIngredientsDraft with _$MealIngredientsDraft {
  const factory MealIngredientsDraft({
    required Ingredient ingredient,
    required IngredientPortionDraft ingredientPortion,
    required int amount,
    required double quantityConfidence,
  }) = _MealIngredientsDraft;
}

@freezed
abstract class MealDraft with _$MealDraft {
  const factory MealDraft({
    required String name,
    required List<MealIngredientsDraft> mealIngredients,
    required DateTime plannedAt,
    required String status,
    String? notes,
    int? mealTemplateId,
  }) = _MealDraft;
}
