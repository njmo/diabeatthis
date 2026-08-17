import 'dart:math';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/meal.dart' as domain;
import '../../../../../core/drift/providers/database_provider.dart';
import '../../providers/meal_status_history_provider.dart';

part 'complete_bolus_wait_use_case.g.dart';

@Riverpod(keepAlive: true)
CompleteBolusWaitUseCase completeBolusWaitUseCase(Ref ref) {
  return CompleteBolusWaitUseCase(ref: ref);
}

class CompleteBolusWaitUseCase {
  final Ref ref;

  const CompleteBolusWaitUseCase({required this.ref});

  Future<void> call(domain.Meal meal) async {
    final db = ref.read(databaseProvider);
    final finalWaitMinutes = await _finalWaitMinutes(meal);

    await db.transaction(() async {
      if (finalWaitMinutes != null) {
        final initialWaitTime = await db.mealAdvisorResultDao
            .getMealAdvisorResultInitialWaitTime(meal.id);
        final waitTimeIgnored =
            initialWaitTime != null && finalWaitMinutes < initialWaitTime;

        await db.mealAdvisorResultDao.updateAdvisorResultWaitOutcome(
          mealId: meal.id,
          finalWaitTime: finalWaitMinutes,
          waitTimeIgnored: waitTimeIgnored,
        );
      }

      await db.mealDao.updateMealStatus(meal.id, 'waited-eating');
    });
  }

  Future<int?> _finalWaitMinutes(domain.Meal meal) async {
    final startedAt =
        await ref.read(
          mealStatusStartedAtProvider(
            MealStatusStartedAtRequest(
              mealId: meal.id,
              status: 'bolused-waiting',
            ),
          ).future,
        ) ??
        meal.updatedAt;
    if (startedAt == null) {
      return null;
    }

    return max(0, clock.now().difference(startedAt).inMinutes);
  }
}
