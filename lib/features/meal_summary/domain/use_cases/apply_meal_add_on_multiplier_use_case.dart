import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_activation_guard.dart';
import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
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
    if (currentMealStatus == null ||
        !(mealStatusesStartingEating.contains(currentMealStatus) ||
            mealStatusReadyToSummarize(currentMealStatus) ||
            currentMealStatus == 'eating-extra' ||
            currentMealStatus == 'summarized') ||
        !multiplier.isFinite ||
        multiplier <= 0) {
      throw MealActivationException(lang.mealCompletionStale);
    }

    final result = await db.transaction(() async {
      await ensureMealActivationAllowed(
        db,
        mealId,
        allowedStatuses: {currentMealStatus},
      );
      final before = _netCarbs(
        await db.ingredientDao.totalsForMealConsumed(mealId),
      );
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

      if (!await db.mealDao.tryUpdateMealStatus(
        mealId,
        mealStatusAfterAddOn(currentMealStatus),
      )) {
        throw MealActivationException(lang.mealCompletionStale);
      }
      final total = _netCarbs(
        await db.ingredientDao.totalsForMealConsumed(mealId),
      );
      return MealAddOnMultiplierResult(
        addedNetCarbs: total - before,
        totalNetCarbs: total,
      );
    });
    ref.invalidate(getMealIngredientsDraftForMealProvider(mealId));
    ref.invalidate(mealMacronutrientsConsumedSummaryProvider(mealId));

    logI(
      'Applied meal $mealId add-on multiplier $multiplier: '
      '${result.addedNetCarbs}g net carbs added',
    );

    return result;
  }

  double _netCarbs(MealMacroSummary? summary) {
    if (summary == null) {
      return 0;
    }
    return summary.netCarbsGrams;
  }
}
