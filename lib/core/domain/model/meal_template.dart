import 'package:freezed_annotation/freezed_annotation.dart';
import 'meal_template_ingredient.dart';

part 'meal_template.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class MealTemplate with _$MealTemplate {
  const factory MealTemplate.existing({
    required int id,
    required String name,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool isFavorite,
    int? createdFromMealId,
    required bool isSynced,
  }) = _MealTemplateExisting;

  const factory MealTemplate.view({
    required String name,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool isFavorite,
    int? createdFromMealId,
    required bool isSynced,
    required List<MealTemplateIngredient> ingredients,
}) = _MealTemplateView;

  const factory MealTemplate.draft({
    required String name,
    String? notes,
    int? createdFromMealId,
    required bool isFavorite,
  }) = _MealTemplateDraft;

  const factory MealTemplate.empty() = _MealTemplateEmpty;
}
