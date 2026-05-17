import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../../core/drift/providers/database_provider.dart';

part 'update_ingredient_details_use_case.g.dart';

@Riverpod(keepAlive: true)
UpdateIngredientDetailsUseCase updateIngredientDetailsUseCase(Ref ref) {
  return UpdateIngredientDetailsUseCase(ref: ref);
}

class UpdateIngredientDetailsUseCase {
  final Ref ref;

  UpdateIngredientDetailsUseCase({required this.ref});

  Future<void> call(domain.Ingredient ingredient) async {
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
    if (existing.carbsPer100g < 0 ||
        existing.fatPer100g < 0 ||
        fiberPer100g < 0 ||
        existing.proteinPer100g < 0) {
      throw ArgumentError('Ingredient macros cannot be negative');
    }
    if (existing.nutritionConfidence < 0 || existing.nutritionConfidence > 1) {
      throw ArgumentError('Nutrition confidence must be between 0 and 1');
    }

    final db = ref.read(databaseProvider);
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
    );
  }
}
