import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../drafts/ingredient_draft.dart';
import '../../drafts/ingredient_draft_validation.dart';

part 'update_ingredient_details_use_case.g.dart';

@Riverpod(keepAlive: true)
UpdateIngredientDetailsUseCase updateIngredientDetailsUseCase(Ref ref) {
  return UpdateIngredientDetailsUseCase(ref: ref);
}

class UpdateIngredientDetailsUseCase {
  final Ref ref;

  UpdateIngredientDetailsUseCase({required this.ref});

  Future<void> call(IngredientDraft ingredient) async {
    final existing = ingredient.map(
      existing: (value) => value,
      draft: (_) =>
          throw StateError('Cannot update ingredient draft without id'),
    );
    final name = existing.name.trim();
    final fiberPer100g = existing.isReference ? 0.0 : existing.fiberPer100g;
    if (name.length < 2) {
      throw ArgumentError('Ingredient name must be at least 2 characters');
    }

    final db = ref.read(databaseProvider);
    final saved = await db.ingredientDao.getIngredientById(existing.id);
    final savedLabelMode = CarbsLabelModeX.fromStorage(saved.carbsLabelMode);
    final updated = existing.copyWith(
      fiberPer100g: fiberPer100g,
      carbsLabelMode: savedLabelMode,
      barcode: existing.normalizedBarcode,
    );

    updated.validateMacroRanges();
    updated.validateBarcode();
    if (existing.nutritionConfidence < 0 || existing.nutritionConfidence > 1) {
      throw ArgumentError('Nutrition confidence must be between 0 and 1');
    }

    await db.ingredientDao.updateIngredientDetails(
      ingredientId: existing.id,
      name: name,
      carbsPer100g: existing.carbsPer100g,
      fatPer100g: existing.fatPer100g,
      fiberPer100g: fiberPer100g,
      proteinPer100g: existing.proteinPer100g,
      nutritionConfidence: existing.nutritionConfidence,
      isReference: existing.isReference,
      brand: existing.brand,
      barcode: existing.normalizedBarcode,
    );
  }

  Future<void> updatePortionAmount({
    required int ingredientId,
    required int portionId,
    required double gramsPerPortion,
  }) async {
    if (gramsPerPortion <= 0) {
      throw ArgumentError('Portion amount must be greater than zero');
    }

    final db = ref.read(databaseProvider);
    await db.portionDao.updateIngredientPortionAmount(
      ingredientId: ingredientId,
      portionId: portionId,
      gramsPerPortion: gramsPerPortion,
    );
  }
}
