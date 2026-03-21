import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal_template.freezed.dart';

@freezed
abstract class MealTemplate with _$MealTemplate {
  const factory MealTemplate({
    required int id,
    required String name,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool isFavorite,
    int? createdFromMealId,
    required bool isSynced,
  }) = _MealTemplateExisting;
}
