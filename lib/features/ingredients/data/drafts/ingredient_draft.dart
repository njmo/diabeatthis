import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../portions/data/drafts/portion_draft.dart';

part 'ingredient_draft.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class IngredientSelection with _$IngredientSelection
{
  const factory IngredientSelection.draft({
    required String name,
    required double carbsPer100g,
    required double fatPer100g,
    required double fiberPer100g,
    required double proteinPer100g,
    required double nutritionConfidence,
    required bool isReference,
    double? caloriesKcalPer100g,
    int? ig,
    String? preparation,
    String? brand,
  }) = _IngredientSelectionDraft;

  const factory IngredientSelection.existing({
    required int id,
    required String name,
    required double carbsPer100g,
    required double fatPer100g,
    required double fiberPer100g,
    required double proteinPer100g,
    required double nutritionConfidence,
    required bool isReference,
    double? caloriesKcalPer100g,
    int? ig,
    String? preparation,
    String? brand,
    }) = _IngredientSelectionExisting;
}

@freezed
abstract class IngredientPortionDraft with _$IngredientPortionDraft
{
  const factory IngredientPortionDraft( {
    required PortionSelection portion,
    required int amount,
  }) = _IngredientPortionDraft;
}