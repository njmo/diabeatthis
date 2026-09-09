import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../providers/meal_snapshot_controller_provider.dart';
import '../repositories/meal_advisor_result_store.dart';
import '../utils/meal_advisor.dart';
import 'meal_advisor_result_use_case.dart';

class AcceptMealDecisionUseCase {
  final Ref ref;
  const AcceptMealDecisionUseCase(this.ref);

  Future<void> call(int mealId, MealAdvice advice) async {
    final decision = advice.decision;
    if (decision == null) {
      throw StateError('Cannot accept an empty meal decision');
    }
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await MealAdvisorResultUseCase(
        DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
      ).saveMealAdvice(mealId, advice);
      await ref
          .read(mealSnapshotControllerProvider)
          .createPlannedSnapshot(mealId);
      await db.mealDao.updateMealStatus(mealId, decision.acceptedStatus);
    });
  }
}
