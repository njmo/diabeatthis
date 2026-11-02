import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/common/meal/meal_bolus_coverage.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/utils/meal_completion_amounts.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../helpers/delivered_meal_bolus.dart';
import 'record_meal_add_on_use_case_test.dart' show addOnDraft, seedAddOnMeal;

void main() {
  final start = DateTime(2026, 11, 2, 12);
  final addOnAt = start.add(const Duration(minutes: 10));
  final end = start.add(const Duration(minutes: 20));
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
    await seedAddOnMeal(db, start);
    final draft = await addOnDraft(db, meat: 200);
    await withClock(
      Clock.fixed(addOnAt),
      () => container.read(recordMealAddOnUseCaseProvider).call(draft),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<MealBolusCoverage> reviewedCoverage() async => readMealBolusCoverage(
    db,
    1,
    context: await readMealAddOnBolusContext(db, 1),
  );

  Future<MealCompletionResult> save(MealSummaryDraft draft) => withClock(
    Clock.fixed(end),
    () => container
        .read(completeMealUseCaseProvider)
        .call(
          draft: draft,
          choice: inferMealCompletionChoice(draft),
          endedAt: end,
        ),
  );

  test(
    'calculator arriving after review rejects same-status completion without changing amounts',
    () async {
      final reviewed = await reviewedCoverage();
      final draft = (await addOnDraft(
        db,
        meat: 150,
      )).copyWith(reviewedBolusCoverage: reviewed);
      expect(reviewed.carbs, 0);
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('after-review','aaps',?,44)",
        [addOnAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, addOnAt.add(const Duration(minutes: 1)));

      await expectLater(
        save(draft),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );

      final meal = (await db.mealDao.getMealById(1))!;
      expect(meal.status, 'eating-extra');
      expect(meal.consumptionConfirmedEndedAt, isNull);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).map((row) => row.consumedAmount),
        [200, 200],
      );
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
      expect(await db.select(db.bolusWizard).get(), hasLength(1));
      expect(await db.mealWizardLinkDao.forMeal(1), isEmpty);

      // Refreshing the review reconciles real evidence before asking the user to
      // confirm the newly relevant shortfall; their quantities remain untouched.
      await reconcileMealAddOnBolusProgress(db, 1);
      final refreshed = await reviewedCoverage();
      expect(refreshed.carbs, 44);
      final result = await save(
        draft.copyWith(reviewedBolusCoverage: refreshed),
      );
      expect(result.requiresBolus, isFalse);
      expect((await db.mealDao.getMealById(1))!.status, 'summarized');
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).first.consumedAmount,
        150,
      );
    },
  );

  test(
    'matching reviewed coverage permits actual quantities and the remaining bolus request',
    () async {
      final draft = (await addOnDraft(
        db,
        meat: 150,
      )).copyWith(reviewedBolusCoverage: await reviewedCoverage());
      final result = await save(draft);
      expect(result.requiresBolus, isTrue);
      expect(result.aapsCarbs!.carbs, 43);
      expect((await db.mealDao.getMealById(1))!.status, 'waiting-for-bolus');
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).first.consumedAmount,
        150,
      );
    },
  );

  test(
    'changed bolus evidence invalidates review even when covered carbs remain unchanged',
    () async {
      final draft = (await addOnDraft(
        db,
        meat: 150,
      )).copyWith(reviewedBolusCoverage: await reviewedCoverage());
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('zero-carbs','aaps',?,0)",
        [addOnAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, addOnAt.add(const Duration(minutes: 1)));
      await db.mealWizardLinkDao.link(
        mealId: 1,
        localWizardId: 'zero-carbs',
        relationType: 'initial',
      );

      await expectLater(
        save(draft),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );

      expect((await db.mealDao.getMealById(1))!.status, 'eating-extra');
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).first.consumedAmount,
        200,
      );
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
    },
  );
}
