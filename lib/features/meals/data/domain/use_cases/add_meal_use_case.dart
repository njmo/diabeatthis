import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../../ingredients/data/drafts/ingredient_draft_validation.dart';
import '../../../../ingredients/data/icons/ingredient_icon_provider.dart';
import '../../../../ingredients/data/persistence/insert_ingredient_draft.dart';
import '../../../../portions/data/persistence/resolve_portion_selection.dart';
import '../../drafts/meal_draft.dart';
import '../../persistence/insert_meal_draft.dart';
import '../../providers/meal_ingredients_list_provider.dart';

part 'add_meal_use_case.g.dart';

@Riverpod(keepAlive: true)
AddMealUseCase addMealUseCase(Ref ref) {
  return AddMealUseCase(ref: ref);
}

class AddMealUseCase with Logging {
  final Ref ref;

  const AddMealUseCase({required this.ref});

  Future<Meal> call(MealDraft draft) async {
    await _validateMealDraft(draft);

    final db = ref.read(databaseProvider);

    final icons = ref.read(ingredientIconServiceProvider);
    final savedIngredients = <IngredientDraft, domain.Ingredient>{};
    final result = await db.transaction(() async {
      logI('Adding ${draft.name}');
      final meal = await insertMealDraft(db, draft);
      logI('Added ${meal.name}');

      for (final mealIngredient in draft.mealIngredients) {
        final ingredientDraft = mealIngredient.ingredient;
        final ingredient =
            savedIngredients[ingredientDraft] ??
            await insertIngredientDraft(
              db,
              ingredientDraft.copyWith(
                iconAssetPath:
                    ingredientDraft.iconAssetPath ??
                    icons.cached(ingredientDraft.name, ingredientDraft.brand),
              ),
            );
        savedIngredients[ingredientDraft] = ingredient;
        logI('Added ${ingredient.name}');

        final portion = await resolvePortionSelection(
          db,
          mealIngredient.ingredientPortion.portion,
        );
        logI('Added ${portion?.name ?? 'no portion'}');

        if (portion != null) {
          await db.insertIngredientPortion(
            ingredient.id,
            portion.id,
            mealIngredient.ingredientPortion.amount,
          );
        }

        await db.insertMealIngredient(
          meal.id,
          ingredient.id,
          portion?.id,
          mealIngredient.amount,
          null,
          mealIngredient.quantityConfidence,
          null,
        );
        logI('Added meal ingredient');
      }

      return meal;
    });
    for (final ingredient in savedIngredients.values) {
      if (ingredient.iconAssetPath == null) {
        unawaited(
          persistIngredientIcon(
            db,
            icons,
            ingredient.id,
            ingredient.name,
            ingredient.brand,
          ),
        );
      }
    }
    return result;
  }

  Future<void> _validateMealDraft(MealDraft draft) async {
    if (draft.mealIngredients.isEmpty) {
      throw ArgumentError(lang.uiAMealMustContainAtLeastOneIngredient);
    }

    for (final mealIngredient in draft.mealIngredients) {
      mealIngredient.ingredient.validateMacroRanges();
      if (!mealIngredient.ingredient.hasEnergyMacros) {
        throw ArgumentError(lang.ingredientEnergyMacrosRequired);
      }
    }

    if (!await _hasActionableCarbs(draft)) {
      throw ArgumentError(lang.mealActionableCarbsRequired);
    }
  }

  Future<bool> _hasActionableCarbs(MealDraft draft) async {
    final macros = await calculateMealIngredientsMacronutrients(
      ref,
      draft.mealIngredients,
    );
    if (macros.netCarbsTotal > 0) {
      return true;
    }

    return macros.extendedCarbsTotal > 0;
  }
}
