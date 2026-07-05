import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/model/carbs_label_mode.dart';

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
    @Default(CarbsLabelMode.eu) CarbsLabelMode carbsLabelMode,
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
    @Default(CarbsLabelMode.eu) CarbsLabelMode carbsLabelMode,
    double? netKcalPer100g,
    double? kcalPer100g,
    double? wbtKcalPer100g,
    int? ig,
    String? preparation,
    String? brand,
  }) = _IngredientDraftExisting;
}

extension IngredientDraftIdentity on IngredientDraft {
  int? getIngredientIdOrNull() {
    return map(draft: (_) => null, existing: (ingredient) => ingredient.id);
  }
}
