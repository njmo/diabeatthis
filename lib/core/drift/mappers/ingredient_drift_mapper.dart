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
    kcalPer100g: kcalPer100g,
    wbtKcalPer100g: wbtKcalPer100g,
    netKcalPer100g: netKcalPer100g,
    brand: brand,
    nutritionConfidence: nutritionConfidence,
    isReference: isReference == 1,
  );
}

extension IngredientDataIterableToDomain on Iterable<IngredientData> {
  List<Ingredient> toDomainList() => map((e) => e.toDomain()).toList();
}
