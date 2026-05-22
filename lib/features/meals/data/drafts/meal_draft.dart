import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';

part 'meal_draft.freezed.dart';

@freezed
abstract class MealIngredientsDraft with _$MealIngredientsDraft {
  const factory MealIngredientsDraft({
    int? mealIngredientId,
    required IngredientDraft ingredient,
    required IngredientPortionDraft ingredientPortion,
    required double amount,
    required double quantityConfidence,
    required String entryType,
    required double? consumedAmount,
    required double? consumedConfidence,
  }) = _MealIngredientsDraft;
}

@freezed
abstract class MealDraft with _$MealDraft {
  const factory MealDraft({
    required String name,
    required List<MealIngredientsDraft> mealIngredients,
    required DateTime plannedAt,
    @Default(MealPurpose.meal) MealPurpose purpose,
    required String status,
    String? notes,
    int? mealTemplateId,
    int? basedOnMealId,
  }) = _MealDraft;
}
