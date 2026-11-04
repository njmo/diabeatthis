import '../../../../common/ingredient_catalog/catalog_ingredient.dart';
import '../../../../common/ingredient_catalog/ingredient_identity.dart';
import '../../../../common/nutrition/catalog_nutrition_confidence.dart';
import 'meal_photo_nutrition.dart';

class MealPhotoCandidate {
  const MealPhotoCandidate({
    required this.identity,
    required this.name,
    required this.nutritionPer100g,
    this.localIngredientId,
    this.catalogRevision,
    this.catalogIngredient,
    this.iconAssetPath,
    this.nutritionConfidence,
    this.nutritionConfidenceAssessed = true,
    this.matchCount = 1,
  });
  final IngredientIdentity identity;
  final int matchCount;

  MealPhotoCandidate withMatchCount(int count) => MealPhotoCandidate(
    identity: identity,
    name: name,
    nutritionPer100g: nutritionPer100g,
    localIngredientId: localIngredientId,
    catalogRevision: catalogRevision,
    catalogIngredient: catalogIngredient,
    iconAssetPath: iconAssetPath,
    nutritionConfidence: nutritionConfidence,
    nutritionConfidenceAssessed: nutritionConfidenceAssessed,
    matchCount: count,
  );
  final String name;
  final MealPhotoNutrition nutritionPer100g;
  final int? localIngredientId;
  final String? catalogRevision;
  final CatalogIngredient? catalogIngredient;
  final String? iconAssetPath;
  final double? nutritionConfidence;
  double get effectiveNutritionConfidence => catalogNutritionConfidence(
    nutritionConfidence,
    assessed: nutritionConfidenceAssessed,
  );
  final bool nutritionConfidenceAssessed;
  String get key => identity.stableKey;
}
