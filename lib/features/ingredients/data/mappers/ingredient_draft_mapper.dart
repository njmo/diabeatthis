import 'package:drift/drift.dart' as d;

import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/drift/entity/ingredient.dart';
import '../drafts/ingredient_draft.dart';

extension DomainIngredientDraftMapper on domain.Ingredient {
  IngredientDraft toDraft() {
    return IngredientDraft.existing(
      id: id,
      name: name,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fiberPer100g: fiberPer100g,
      proteinPer100g: proteinPer100g,
      nutritionConfidence: nutritionConfidence,
      isReference: isReference,
      carbsLabelMode: carbsLabelMode,
      netKcalPer100g: netKcalPer100g,
      kcalPer100g: kcalPer100g,
      wbtKcalPer100g: wbtKcalPer100g,
      ig: ig,
      preparation: preparation,
      brand: brand,
    );
  }
}

extension IngredientDraftDomainMapper on IngredientDraft {
  domain.Ingredient toDomain() {
    return map(
      draft: (_) => throw StateError('Ingredient draft does not have an id'),
      existing: (ingredient) => domain.Ingredient(
        id: ingredient.id,
        name: ingredient.name,
        carbsPer100g: ingredient.carbsPer100g,
        fatPer100g: ingredient.fatPer100g,
        fiberPer100g: ingredient.fiberPer100g,
        proteinPer100g: ingredient.proteinPer100g,
        nutritionConfidence: ingredient.nutritionConfidence,
        isReference: ingredient.isReference,
        carbsLabelMode: ingredient.carbsLabelMode,
        netKcalPer100g: ingredient.netKcalPer100g,
        kcalPer100g: ingredient.kcalPer100g,
        wbtKcalPer100g: ingredient.wbtKcalPer100g,
        ig: ingredient.ig,
        preparation: ingredient.preparation,
        brand: ingredient.brand,
      ),
    );
  }
}

extension IngredientDraftToCompanion on IngredientDraft {
  IngredientCompanion toCompanion() {
    return map(
      draft: (ingredient) => IngredientCompanion(
        name: d.Value(ingredient.name),
        carbsPer100g: d.Value(ingredient.carbsPer100g),
        fatPer100g: d.Value(ingredient.fatPer100g),
        fiberPer100g: d.Value(ingredient.fiberPer100g),
        proteinPer100g: d.Value(ingredient.proteinPer100g),
        carbsLabelMode: d.Value(ingredient.carbsLabelMode.storageValue),
        brand: d.Value(ingredient.brand),
        nutritionConfidence: d.Value(ingredient.nutritionConfidence),
        isReference: d.Value(ingredient.isReference ? 1 : 0),
      ),
      existing: (_) =>
          throw StateError('Existing ingredient draft cannot be inserted'),
    );
  }
}
