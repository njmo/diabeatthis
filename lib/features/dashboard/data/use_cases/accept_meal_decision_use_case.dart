import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal/meal_activation_guard.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../providers/meal_snapshot_controller_provider.dart';
import '../repositories/meal_advisor_result_store.dart';
import '../utils/meal_advisor.dart';
import 'meal_advisor_result_use_case.dart';

class AcceptMealDecisionUseCase {
  final Ref ref;
  const AcceptMealDecisionUseCase(this.ref);

  Future<void> call(
    int mealId,
    MealAdvice advice, {
    bool alreadySaved = false,
    bool Function()? isCancelled,
  }) async {
    final decision = advice.decision;
    if (decision == null) {
      throw StateError('Cannot accept an empty meal decision');
    }
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await ensureMealActivationAllowed(
        db,
        mealId,
        allowedStatuses: const {'planned'},
      );
      if (!alreadySaved) {
        await MealAdvisorResultUseCase(
          DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
        ).saveMealAdvice(mealId, advice);
      }
      await ref
          .read(mealSnapshotControllerProvider)
          .createPlannedSnapshot(mealId);
      if (isCancelled?.call() == true) {
        throw StateError('Meal decision acceptance was cancelled');
      }
      await db.mealDao.tryUpdateMealStatus(mealId, decision.acceptedStatus);
    });
  }
}
