import 'dart:math';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/meal.dart' as domain;
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';

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
    final finalWaitMinutes = await _finalWaitMinutes(db, meal);

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

  Future<int?> _finalWaitMinutes(DatabaseImpl db, domain.Meal meal) async {
    final startedAt = await _bolusWaitStartedAt(db, meal.id) ?? meal.updatedAt;
    if (startedAt == null) {
      return null;
    }

    return max(0, clock.now().difference(startedAt).inMinutes);
  }

  Future<DateTime?> _bolusWaitStartedAt(DatabaseImpl db, int mealId) async {
    final history =
        await (db.select(db.mealStatusHistory)
              ..where((tbl) => tbl.mealId.equals(mealId))
              ..where((tbl) => tbl.status.equals('bolused-waiting')))
            .getSingleOrNull();

    if (history == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(history.createdAt);
  }
}
