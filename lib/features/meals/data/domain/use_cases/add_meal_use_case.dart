import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../ingredients/data/drafts/ingredient_draft_validation.dart';
import '../../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../../portions/data/providers/portion_provider.dart';
import '../../drafts/meal_draft.dart';
import '../../providers/meal_database_provider.dart';

part 'add_meal_use_case.g.dart';

@Riverpod(keepAlive: true)
AddMealUseCase addMealUseCase(Ref ref) {
  return AddMealUseCase(ref: ref);
}

class AddMealUseCase with Logging {
  final Ref ref;

  const AddMealUseCase({required this.ref});

  Future<Meal> call(MealDraft draft) async {
    _validateMealDraft(draft);

    final db = ref.read(databaseProvider);

    return db.transaction(() async {
      logI('Adding ${draft.name}');
      final meal = await ref.read(insertMealProvider(draft).future);
      logI('Added ${meal.name}');

      for (final mealIngredient in draft.mealIngredients) {
        final ingredient = await ref.read(
          insertIngredientProvider(mealIngredient.ingredient).future,
        );
        logI('Added ${ingredient.name}');

        final portion = await ref.read(
          insertPortionProvider(
            mealIngredient.ingredientPortion.portion,
          ).future,
        );
        logI('Added ${portion?.name ?? 'no portion'}');

        await ref.read(
          insertIngredientPortionProvider(
            ingredient,
            portion,
            mealIngredient.ingredientPortion.amount,
          ).future,
        );

        await ref.read(
          insertMealIngredientProvider(
            ingredient,
            meal,
            portion,
            mealIngredient.amount,
            mealIngredient.quantityConfidence,
          ).future,
        );
        logI('Added meal ingredient');
      }

      return meal;
    });
  }

  void _validateMealDraft(MealDraft draft) {
    if (draft.mealIngredients.isEmpty) {
      throw ArgumentError('Posiłek musi zawierać co najmniej jeden składnik.');
    }

    for (final mealIngredient in draft.mealIngredients) {
      if (!mealIngredient.ingredient.hasEnergyMacros) {
        throw ArgumentError(
          'Składnik musi mieć uzupełnione węglowodany, tłuszcz albo białko.',
        );
      }
    }
  }
}
