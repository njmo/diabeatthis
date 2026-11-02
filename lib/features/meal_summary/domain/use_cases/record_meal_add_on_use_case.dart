import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_activation_guard.dart';
import '../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../common/meal/meal_add_on_bolus_progress.dart';
import '../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../common/meal/meal_completion_timing.dart';
import '../../../../common/meal/meal_extended_carbs.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/database_impl.dart' show MealCompanion;
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../presentation/models/meal_summary_draft.dart';
import '../../presentation/utils/meal_summary_carbs_delta.dart';
import '../utils/meal_completion_amounts.dart';
import 'finalize_meal_summary_use_case.dart';
import 'persist_meal_summary_amounts.dart';

final recordMealAddOnUseCaseProvider = Provider<RecordMealAddOnUseCase>(
  (ref) => RecordMealAddOnUseCase(ref: ref),
);

class MealAddOnResult {
  const MealAddOnResult({required this.meal, required this.aapsCarbs});

  final Meal meal;
  final MealSummaryAapsCarbs aapsCarbs;
}

class RecordMealAddOnUseCase {
  const RecordMealAddOnUseCase({required this.ref});

  final Ref ref;

  Future<MealAddOnResult> call(MealSummaryDraft draft) async {
    final status = draft.mealStatus;
    if (status == null ||
        !(mealStatusesStartingEating.contains(status) ||
            status == 'eating-extra' ||
            mealStatusReadyToSummarize(status) ||
            status == 'summarized') ||
        !mealCompletionAmountsValid(draft, inferMealCompletionChoice(draft)) ||
        draft.itemsById.values.any(
          (item) => item.consumedAmount < item.reportedAmount,
        ) ||
        !(draft.extraItems.isNotEmpty ||
            draft.itemsById.values.any(
              (item) => item.consumedAmount > item.reportedAmount,
            ))) {
      throw MealSummaryCannotFinishException(lang.mealCompletionInvalidAmount);
    }
    final db = ref.read(databaseProvider);
    final result = await db.transaction(() async {
      await ensureMealActivationAllowed(
        db,
        draft.mealId,
        allowedStatuses: {status},
      );
      final meal = (await db.mealDao.getMealById(draft.mealId))!;
      final currentItems = await db.mealIngredientsDao
          .getMealIngredientsForMeal(draft.mealId);
      if (currentItems.length != draft.itemsById.length ||
          currentItems.any((item) {
            final original = draft.itemsById[item.id];
            return original == null ||
                ((item.consumedAmount ?? item.amount) - original.reportedAmount)
                        .abs() >
                    0.001;
          })) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
      final previous = await reconcileMealAddOnBolusProgress(db, meal.id);
      final coverage = await readMealBolusCoverage(
        db,
        meal.id,
        context: previous,
      );
      final before = await db.ingredientDao.totalsForMealConsumed(meal.id);
      final previousExtendedCarbs =
          previous?.reportedExtendedCarbs ??
          mealExtendedCarbsFromMacros(before);
      final deferExtendedCarbs =
          (previous?.originalStatus ?? meal.status) == 'eating-then-bolus';
      final history = await (db.select(
        db.mealStatusHistory,
      )..where((row) => row.mealId.equals(meal.id))).get();
      final timing = MealCompletionTiming.fromHistory(
        history.map(
          (row) => (
            status: row.status,
            at: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
          ),
        ),
        currentStatus: meal.status,
      );
      await persistMealSummaryAmounts(ref, draft);
      final totals = await db.ingredientDao.totalsForMealConsumed(meal.id);
      final totalExtendedCarbs = mealExtendedCarbsFromMacros(totals);
      final requestedCarbs = math
          .max(0, (totals?.netCarbsGrams ?? 0) - coverage.carbs)
          .ceil();
      final requestedExtendedCarbs = deferExtendedCarbs
          ? 0
          : math.max(0, totalExtendedCarbs - previousExtendedCarbs);
      final now = clock.now();
      final context = MealAddOnBolusContext(
        originalStatus: previous?.originalStatus ?? meal.status,
        eatingStartedAt:
            previous?.eatingStartedAt ??
            (mealStatusReadyToSummarize(meal.status) ||
                    meal.status == 'summarized'
                ? now
                : timing.startedAt),
        requestedAt: now,
        bolusWindowStartedAt: previous?.awaitingBolus == true
            ? previous!.bolusWindowStartedAt
            : now,
        coveredCarbs: coverage.carbs,
        statusCoveredCarbs:
            previous?.statusCoveredCarbs ?? coverage.statusBaselineCarbs,
        reportedExtendedCarbs: deferExtendedCarbs
            ? previousExtendedCarbs
            : totalExtendedCarbs,
        requestedCarbs: requestedCarbs,
        requestedExtendedCarbs: requestedExtendedCarbs,
        awaitingBolus: requestedCarbs > 0,
        bolusConfirmed: coverage.hasRecordedBolus,
        acceptedWizardKeys: previous?.acceptedWizardKeys ?? const [],
      );
      if (!await db.mealDao.tryUpdateMealStatus(
        meal.id,
        'eating-extra',
        occurredAt: now,
      )) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
      await (db.update(db.meal)..where((row) => row.id.equals(meal.id))).write(
        MealCompanion(addOnBolusContext: Value(context.encode())),
      );
      return MealAddOnResult(
        meal: meal.toDomain().copyWith(status: 'eating-extra'),
        aapsCarbs: MealSummaryAapsCarbs(
          carbs: requestedCarbs,
          extendedCarbs: requestedExtendedCarbs,
        ),
      );
    });
    ref.invalidate(getMealIngredientsDraftForMealProvider(draft.mealId));
    ref.invalidate(mealMacronutrientsConsumedSummaryProvider(draft.mealId));
    return result;
  }
}
