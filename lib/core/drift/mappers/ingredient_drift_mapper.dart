import 'package:drift/drift.dart' as d;

import '../../domain/model/ingredient.dart';
import '../entity/ingredient.dart';

extension IngredientDataToDomain on IngredientData {
  Ingredient toDomain() => Ingredient(
    id: id,
    name: name,
    carbsPer100g: carbsPer100g,
    fatPer100g: fatPer100g,
    fiberPer100g: fiberPer100g,
    proteinPer100g: proteinPer100g,
    caloriesKcalPer100g: caloriesKcalPer100g,
    preparation: preparation,
    brand: brand,
    nutritionConfidence: nutritionConfidence,
    isReference: isReference == 1,
  );
}

extension IngredientDataIterableToDomain on Iterable<IngredientData> {
  List<Ingredient> toDomainList() => map((e) => e.toDomain()).toList();
}

extension DomainIngredientToCompanion on Ingredient {
  IngredientCompanion toCompanion() {
    return IngredientCompanion(
      id: d.Value(id),
      name: d.Value(name),
      carbsPer100g: d.Value(carbsPer100g),
      fatPer100g: d.Value(fatPer100g),
      fiberPer100g: d.Value(fiberPer100g),
      proteinPer100g: d.Value(proteinPer100g),
      preparation: d.Value(preparation),
      brand: d.Value(brand),
      nutritionConfidence: d.Value(nutritionConfidence),
    );
  }
}
