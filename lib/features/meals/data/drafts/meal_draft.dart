import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../common/meal/meal_category.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';

part 'meal_draft.freezed.dart';

@freezed
abstract class MealIngredientsDraft with _$MealIngredientsDraft {
  const factory MealIngredientsDraft({
    int? mealIngredientId,
    String? catalogId,
    String? catalogRevision,
    @Default(true) bool catalogReviewed,
    double? recordedGramsPerAmount,
    required IngredientDraft ingredient,
    required IngredientPortionDraft ingredientPortion,
    required double amount,
    required double quantityConfidence,
    double? nutritionConfidenceOverride,
    required String entryType,
    required double? consumedAmount,
    required double? consumedConfidence,
  }) = _MealIngredientsDraft;
}

@freezed
abstract class MealDraft with _$MealDraft {
  const factory MealDraft({
    required String name,
    MealCategory? category,
    required List<MealIngredientsDraft> mealIngredients,
    required DateTime plannedAt,
    String? plannedDay,
    @Default(MealPurpose.meal) MealPurpose purpose,
    required String status,
    String? notes,
    int? mealTemplateId,
    int? basedOnMealId,
  }) = _MealDraft;
}
