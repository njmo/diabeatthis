import '../../../common/ingredient_catalog/ingredient_identity.dart';
import '../../ingredients/data/drafts/ingredient_draft.dart';
import '../../ingredients/data/drafts/ingredient_draft_validation.dart';
import '../domain/models/meal_photo_candidate.dart';
import '../domain/models/meal_photo_nutrition.dart';

class MealPhotoBarcodeCandidateFactory {
  const MealPhotoBarcodeCandidateFactory();

  MealPhotoCandidate call(IngredientDraft draft) {
    draft.validateMacroRanges();
    draft.validateBarcode();
    if (draft.isReference || draft.name.trim().isEmpty) {
      throw ArgumentError(
        'A barcode product requires a name and ordinary nutrition',
      );
    }
    final id = draft.getIngredientIdOrNull();
    final barcode = draft.normalizedBarcode;
    if (id == null && barcode == null) {
      throw ArgumentError('A new barcode product requires its scanned code');
    }
    return MealPhotoCandidate(
      identity: IngredientIdentity(
        source: id == null ? IngredientSource.barcode : IngredientSource.local,
        sourceId: id?.toString() ?? barcode!,
      ),
      name: draft.name.trim(),
      localIngredientId: id,
      barcode: barcode,
      brand: draft.brand,
      nutritionConfidence: draft.nutritionConfidence,
      nutritionConfidenceAssessed: true,
      iconAssetPath: draft.iconAssetPath,
      nutritionPer100g: MealPhotoNutrition(
        carbs: draft.carbsPer100g,
        fiber: draft.fiberPer100g,
        fat: draft.fatPer100g,
        protein: draft.proteinPer100g,
        carbsLabelMode: draft.carbsLabelMode,
      ),
    );
  }
}
