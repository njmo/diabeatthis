import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import 'complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;

void main() {
  final start = DateTime(2026, 11, 2, 8);
  final end = start.add(const Duration(minutes: 15));
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(
          FakeNotificationsController(),
        ),
      ],
    );
    await seedCompletionMeal(db);
    await db.mealDao.updateMealStatus(
      1,
      'eating-then-bolus',
      occurredAt: start,
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  for (final consumed in [50.0, 75.0]) {
    test(
      'existing eat-first summary can be saved after bolus with $consumed g',
      () async {
        final complete = container.read(completeMealUseCaseProvider);
        await withClock(
          Clock.fixed(end),
          () => complete.call(
            draft: completionDraft(status: 'eating-then-bolus'),
            choice: MealCompletionChoice.less,
            endedAt: end,
          ),
        );
        final original = (await db.select(db.mealSnapshot).get()).single;
        expect((await db.mealDao.getMealById(1))!.status, 'waiting-for-bolus');
        final bolusAt = end.add(const Duration(minutes: 1));
        await db.customStatement(
          "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('confirmed','aaps',?,10)",
          [bolusAt.millisecondsSinceEpoch],
        );
        await db.mealWizardLinkDao.link(
          mealId: 1,
          localWizardId: 'confirmed',
          relationType: 'initial',
        );
        await db.mealDao.updateMealStatus(
          1,
          'eaten-bolused',
          occurredAt: bolusAt,
        );

        final result = await withClock(
          Clock.fixed(bolusAt),
          () => complete.call(
            draft: completionDraft(
              status: 'eaten-bolused',
              reported: 50,
              consumed: consumed,
            ),
            choice: consumed == 50
                ? MealCompletionChoice.all
                : MealCompletionChoice.more,
            endedAt: end,
          ),
        );

        final snapshot = (await db.select(db.mealSnapshot).get()).single;
        expect(snapshot.id, original.id);
        expect(snapshot.totalGrams, consumed);
        expect(snapshot.totalNetCarbsG, consumed * 0.2);
        expect(result.requiresBolus, isFalse);
        expect(result.aapsCarbs!.carbs, (consumed * 0.2 - 10).ceil());
        expect((await db.mealDao.getMealById(1))!.status, 'summarized');
        final history = await db.select(db.mealStatusHistory).get();
        expect(
          history.singleWhere((row) => row.status == 'eaten-bolused').createdAt,
          bolusAt.millisecondsSinceEpoch,
        );
        expect(
          (await db.mealIngredientsDao.getMealIngredientsForMeal(
            1,
          )).single.consumedAmount,
          consumed,
        );
      },
    );
  }

  test(
    'repeated planned snapshot keeps its identity and the consumed snapshot',
    () async {
      final snapshots = container.read(mealSnapshotControllerProvider);
      await snapshots.createPlannedSnapshot(1);
      await snapshots.saveConsumedSnapshot(1);
      final before = await db.select(db.mealSnapshot).get();

      await snapshots.createPlannedSnapshot(1);

      final after = await db.select(db.mealSnapshot).get();
      expect(after.map((row) => row.id), before.map((row) => row.id));
      expect(after.map((row) => row.snapshotType), ['planned', 'consumed']);
    },
  );
}
