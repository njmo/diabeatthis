import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/drafts/ingredient_draft_validation.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/mappers/quick_low_treatment_item_draft_mapper.dart';

part 'upsert_quick_low_treatment_item_use_case.g.dart';

@riverpod
UpsertQuickLowTreatmentItemUseCase upsertQuickLowTreatmentItemUseCase(Ref ref) {
  return UpsertQuickLowTreatmentItemUseCase(ref: ref);
}

class UpsertQuickLowTreatmentItemUseCase {
  const UpsertQuickLowTreatmentItemUseCase({required this.ref});

  final Ref ref;

  Future<QuickLowTreatmentItem> call({
    required int slot,
    required MealIngredientsDraft mealIngredient,
    QuickLowTreatmentItem? existingItem,
  }) async {
    _validateQuickLowTreatmentItem(slot: slot, mealIngredient: mealIngredient);

    final db = ref.read(databaseProvider);

    return db.transaction(() async {
      final ingredient = await ref.read(
        insertIngredientProvider(mealIngredient.ingredient).future,
      );
      final portion = await ref.read(
        insertPortionProvider(mealIngredient.ingredientPortion.portion).future,
      );
      await ref.read(
        insertIngredientPortionProvider(
          ingredient,
          portion,
          mealIngredient.ingredientPortion.amount,
        ).future,
      );

      final item = mealIngredient.toQuickLowTreatmentItemCompanion(
        ingredient: ingredient,
        portion: portion,
        sortOrder: slot,
      );

      if (existingItem == null) {
        return db.quickLowTreatmentItemDao.insertQuickLowTreatmentItem(item);
      }

      return db.quickLowTreatmentItemDao.updateQuickLowTreatmentItem(
        existingItem.id,
        item,
      );
    });
  }

  void _validateQuickLowTreatmentItem({
    required int slot,
    required MealIngredientsDraft mealIngredient,
  }) {
    if (slot < 1 || slot > maxQuickLowTreatmentItems) {
      throw RangeError.range(slot, 1, maxQuickLowTreatmentItems, 'slot');
    }
    if (!mealIngredient.ingredient.hasEnergyMacros) {
      throw ArgumentError(
        'Składnik musi mieć uzupełnione węglowodany, tłuszcz albo białko.',
      );
    }
    if (mealIngredient.amount <= 0) {
      throw ArgumentError('Ilość szybkiego dosłodzenia musi być większa od 0.');
    }
    final hasPortion = mealIngredient.ingredientPortion.portion.maybeMap(
      empty: (_) => false,
      orElse: () => true,
    );
    if (hasPortion && mealIngredient.ingredientPortion.amount <= 0) {
      throw ArgumentError('Waga porcji musi być większa od 0 g.');
    }
  }
}
