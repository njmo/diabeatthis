import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/providers/database_provider.dart';
import '../../models/ingredient_edit_draft.dart';

part 'update_ingredient_details_use_case.g.dart';

@Riverpod(keepAlive: true)
UpdateIngredientDetailsUseCase updateIngredientDetailsUseCase(Ref ref) {
  return UpdateIngredientDetailsUseCase(ref: ref);
}

class UpdateIngredientDetailsUseCase {
  final Ref ref;

  UpdateIngredientDetailsUseCase({required this.ref});

  Future<void> call(IngredientEditDraft draft) async {
    final name = draft.name.trim();
    if (name.length < 2) {
      throw ArgumentError('Ingredient name must be at least 2 characters');
    }
    if (draft.carbsPer100g < 0 ||
        draft.fatPer100g < 0 ||
        draft.fiberPer100g < 0 ||
        draft.proteinPer100g < 0) {
      throw ArgumentError('Ingredient macros cannot be negative');
    }
    if (draft.nutritionConfidence < 0 || draft.nutritionConfidence > 1) {
      throw ArgumentError('Nutrition confidence must be between 0 and 1');
    }

    final db = ref.read(databaseProvider);
    await db.ingredientDao.updateIngredientDetails(
      ingredientId: draft.ingredientId,
      name: name,
      carbsPer100g: draft.carbsPer100g,
      fatPer100g: draft.fatPer100g,
      fiberPer100g: draft.fiberPer100g,
      proteinPer100g: draft.proteinPer100g,
      nutritionConfidence: draft.nutritionConfidence,
    );
  }
}
