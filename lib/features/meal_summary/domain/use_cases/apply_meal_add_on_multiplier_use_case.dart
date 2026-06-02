import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../utils/meal_add_on_status.dart';

final applyMealAddOnMultiplierUseCaseProvider =
    Provider<ApplyMealAddOnMultiplierUseCase>((ref) {
      return ApplyMealAddOnMultiplierUseCase(ref: ref);
    });

class MealAddOnMultiplierResult {
  const MealAddOnMultiplierResult({
    required this.addedNetCarbs,
    required this.totalNetCarbs,
  });

  final double addedNetCarbs;
  final double totalNetCarbs;

  int get roundedAddedNetCarbs => addedNetCarbs.ceil();
  int get roundedTotalNetCarbs => totalNetCarbs.ceil();
}

class ApplyMealAddOnMultiplierUseCase with Logging {
  ApplyMealAddOnMultiplierUseCase({required this.ref});

  final Ref ref;

  Future<MealAddOnMultiplierResult> call({
    required int mealId,
    required String? currentMealStatus,
    required double multiplier,
  }) async {
    final db = ref.read(databaseProvider);
    final before = _netCarbs(
      await db.ingredientDao.totalsForMealConsumed(mealId),
    );

    await db.transaction(() async {
      final mealIngredients = await db.mealIngredientsDao
          .getMealIngredientsForMeal(mealId);

      for (final mealIngredient in mealIngredients) {
        if (mealIngredient.entryType == 'extra') {
          continue;
        }

        await db.mealIngredientsDao.updateMealIngredientConsumed(
          mealIngredient.id,
          mealIngredient.amount * multiplier,
          mealIngredient.quantityConfidence,
        );
      }

      await db.mealDao.updateMealStatus(
        mealId,
        mealStatusAfterAddOn(currentMealStatus),
      );
    });

    final total = _netCarbs(
      await db.ingredientDao.totalsForMealConsumed(mealId),
    );

    logI(
      'Applied meal $mealId add-on multiplier $multiplier: '
      '${total - before}g net carbs added',
    );

    return MealAddOnMultiplierResult(
      addedNetCarbs: total - before,
      totalNetCarbs: total,
    );
  }

  double _netCarbs(MealMacroSummary? summary) {
    if (summary == null) {
      return 0;
    }
    return summary.netCarbsGrams;
  }
}
