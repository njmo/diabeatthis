import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../core/domain/model/ingredient.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../../features/ingredients/data/icons/food_icon_assets.dart';

/// Converts a cloud projection into the same presentation model as local data.
Ingredient familyIngredientView(Map row) {
  final data = row['payload'] as Map;
  final carbs = (data['carbs_per_100g'] as num).toDouble();
  final protein = (data['protein_per_100g'] as num).toDouble();
  final fat = (data['fat_per_100g'] as num).toDouble();
  final fiber = (data['fiber_per_100g'] as num).toDouble();
  final labelMode = CarbsLabelModeX.fromStorage(
    data['carbs_label_mode'] as String?,
  );
  final icon = data['icon_asset_path'] as String?;
  return Ingredient(
    kcalPer100g: protein * 4 + carbs * 4 + fat * 9,
    wbtKcalPer100g: protein * 4 + fat * 9,
    netKcalPer100g: calculateNetKcalPer100g(
      carbsPer100g: carbs,
      fiberPer100g: fiber,
      fatPer100g: fat,
      proteinPer100g: protein,
      labelMode: labelMode,
    ),
    id: int.parse('${row['id']}'),
    name: data['name'] as String,
    carbsPer100g: (data['carbs_per_100g'] as num).toDouble(),
    fatPer100g: (data['fat_per_100g'] as num).toDouble(),
    proteinPer100g: (data['protein_per_100g'] as num).toDouble(),
    fiberPer100g: (data['fiber_per_100g'] as num).toDouble(),
    nutritionConfidence:
        (data['nutrition_confidence'] as num?)?.toDouble() ?? 0,
    isReference: data['is_reference'] == 1,
    carbsLabelMode: CarbsLabelModeX.fromStorage(
      data['carbs_label_mode'] as String?,
    ),
    brand: data['brand'] as String?,
    barcode: data['barcode'] as String?,
    // Device-local photo paths are never resolved on a caregiver's phone.
    iconAssetPath: FoodIconAssets.contains(icon) ? icon : null,
    ig: data['ig'] as int?,
  );
}
