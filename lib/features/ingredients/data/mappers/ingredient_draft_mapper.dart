import 'package:drift/drift.dart' as d;

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../data/drafts/ingredient_draft.dart';

extension IngredientDraftMapper on domain.Ingredient {
  IngredientSelection toSelection() {
    return IngredientSelection.existing(
      id: id,
      name: name,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      proteinPer100g: proteinPer100g,
      fiberPer100g: fiberPer100g,
    );
  }
}

extension IngredientMapper on IngredientSelection
{

}

extension IngredientSelectionToCompanion on IngredientSelection {
  IngredientCompanion toCompanion() {
    final idValue = maybeMap<d.Value<int>>(
      existing: (e) => d.Value(e.id),
      orElse: () => const d.Value.absent(),
    );

    return IngredientCompanion(
      id: idValue,
      name: d.Value(name),
      carbsPer100g: d.Value(carbsPer100g),
      fatPer100g: d.Value(fatPer100g),
      proteinPer100g: d.Value(proteinPer100g),
      fiberPer100g: d.Value(fiberPer100g),
    );
  }

  domain.Ingredient toDomain()
  {
    final idValue = maybeMap<int>(
      existing: (e) => e.id,
      orElse: () => 0,
    );

    return domain.Ingredient(
      id : idValue,
      name: name,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      proteinPer100g: proteinPer100g,
      fiberPer100g: fiberPer100g,
    );
  }
}