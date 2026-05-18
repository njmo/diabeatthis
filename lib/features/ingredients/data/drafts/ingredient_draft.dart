import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient_draft.freezed.dart';

@freezed
abstract class IngredientDraft with _$IngredientDraft {
  const factory IngredientDraft.draft({
    required String name,
    required double carbsPer100g,
    required double fatPer100g,
    required double fiberPer100g,
    required double proteinPer100g,
    required double nutritionConfidence,
    required bool isReference,
    double? netKcalPer100g,
    double? kcalPer100g,
    double? wbtKcalPer100g,
    int? ig,
    String? preparation,
    String? brand,
  }) = _IngredientDraftNew;

  const factory IngredientDraft.existing({
    required int id,
    required String name,
    required double carbsPer100g,
    required double fatPer100g,
    required double fiberPer100g,
    required double proteinPer100g,
    required double nutritionConfidence,
    required bool isReference,
    double? netKcalPer100g,
    double? kcalPer100g,
    double? wbtKcalPer100g,
    int? ig,
    String? preparation,
    String? brand,
  }) = _IngredientDraftExisting;
}
