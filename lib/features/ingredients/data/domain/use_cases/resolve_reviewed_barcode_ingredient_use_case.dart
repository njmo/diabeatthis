import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../drafts/ingredient_draft.dart';
import '../../drafts/ingredient_draft_validation.dart';
import '../../mappers/ingredient_draft_mapper.dart';
import '../../persistence/insert_ingredient_draft.dart';

/// Runs inside the caller's transaction; never mutates an existing product.
class ResolveReviewedBarcodeIngredientUseCase {
  const ResolveReviewedBarcodeIngredientUseCase(this.db);
  final DatabaseImpl db;

  Future<IngredientDraft> call(IngredientDraft draft) async {
    draft.validateMacroRanges();
    draft.validateBarcode();
    final barcode = draft.normalizedBarcode;
    if (barcode == null || draft.isReference) {
      throw ArgumentError('Expected a reviewed barcode product');
    }
    final existing = await db.ingredientDao
        .getIngredientByBarcode(barcode)
        .getSingleOrNull();
    if (existing != null) {
      final value = existing.toDomain();
      if (value.isReference ||
          value.carbsPer100g != draft.carbsPer100g ||
          value.fiberPer100g != draft.fiberPer100g ||
          value.proteinPer100g != draft.proteinPer100g ||
          value.fatPer100g != draft.fatPer100g ||
          value.carbsLabelMode != draft.carbsLabelMode) {
        throw StateError(
          'Barcode nutrition changed; review the existing product',
        );
      }
      return value.toDraft();
    }
    return (await insertIngredientDraft(db, draft)).toDraft();
  }
}
