import 'package:freezed_annotation/freezed_annotation.dart';

import 'carbs_label_mode.dart';

part 'ingredient.freezed.dart';
part 'ingredient.g.dart';

@freezed
abstract class Ingredient with _$Ingredient {
  const factory Ingredient({
    required int id,
    required String name,
    required double carbsPer100g,
    required double fatPer100g,
    required double fiberPer100g,
    required double proteinPer100g,
    required double nutritionConfidence,
    required bool isReference,
    @Default(CarbsLabelMode.eu) CarbsLabelMode carbsLabelMode,
    double? netKcalPer100g,
    double? kcalPer100g,
    double? wbtKcalPer100g,
    int? ig,
    String? preparation,
    String? brand,
  }) = _Ingredient;

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);
}
