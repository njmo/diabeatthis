import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/domain/model/meal.dart' as domain;
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../drafts/meal_draft.dart';
import '../../models/retrospective_meal_timing.dart';
import '../../persistence/record_retrospective_meal_history.dart';
import 'add_meal_use_case.dart';

class LogRetrospectiveMealUseCase {
  final Ref ref;
  const LogRetrospectiveMealUseCase(this.ref);

  Future<domain.Meal> call(
    MealDraft draft,
    RetrospectiveMealTiming timing,
  ) async {
    final now = clock.now();
    timing.validate(draft.plannedAt, now);
    final history = timing.history(draft.plannedAt);
    final db = ref.read(databaseProvider);
    return db.transaction(() async {
      final meal = await ref
          .read(addMealUseCaseProvider)
          .call(draft.copyWith(status: 'planned'));
      await (db.update(
        db.mealIngredients,
      )..where((row) => row.mealId.equals(meal.id))).write(
        MealIngredientsCompanion.custom(
          consumedAmount: const CustomExpression('amount'),
          consumedConfidence: const Constant(1.0),
        ),
      );
      final snapshotController = ref.read(mealSnapshotControllerProvider);
      await snapshotController.createPlannedSnapshot(meal.id);
      await snapshotController.saveConsumedSnapshot(meal.id);
      await (db.update(db.meal)..where((row) => row.id.equals(meal.id))).write(
        MealCompanion(
          createdAt: Value(history.values.first.millisecondsSinceEpoch),
        ),
      );
      await recordRetrospectiveMealHistory(
        db,
        meal.id,
        timing,
        draft.plannedAt,
      );
      return meal.copyWith(
        status: 'summarized',
        createdAt: history.values.first,
        updatedAt: history.values.last,
      );
    });
  }
}
