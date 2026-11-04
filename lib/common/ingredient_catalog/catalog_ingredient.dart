import '../../core/domain/model/carbs_label_mode.dart';
import 'ingredient_identity.dart';

/// Canonical nutrition is per 100 g. Display translations never own nutrition.
class CatalogIngredient {
  const CatalogIngredient({
    required this.identity,
    required this.name,
    required this.englishName,
    required this.revision,
    required this.carbsPer100g,
    required this.fiberPer100g,
    required this.fatPer100g,
    required this.proteinPer100g,
    required this.carbsLabelMode,
    this.sourceName,
    this.details = '',
    this.languageCode = 'en',
    this.iconAssetPath,
    this.kcalPer100g,
  });
  final IngredientIdentity identity;
  final String name;
  final String? englishName;
  final String? sourceName;
  final String revision;
  final String details;
  final String languageCode;
  final String? iconAssetPath;
  final double carbsPer100g;
  final double fiberPer100g;
  final double fatPer100g;
  final double proteinPer100g;
  final double? kcalPer100g;
  final CarbsLabelMode carbsLabelMode;
  double get netCarbsPer100g => carbsLabelMode == CarbsLabelMode.nonEu
      ? (carbsPer100g - fiberPer100g).clamp(0, double.infinity).toDouble()
      : carbsPer100g;
}
