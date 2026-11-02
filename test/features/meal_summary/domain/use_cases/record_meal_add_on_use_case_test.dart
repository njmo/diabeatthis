import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_activation_guard.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/utils/meal_completion_amounts.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/tasks/meal_monitor_test.dart'
    show testBolusWizard;
import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../helpers/delivered_meal_bolus.dart';

void main() {
  final start = DateTime(2026, 11, 2, 12);
  final now = start.add(const Duration(minutes: 10));
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
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedWithStatus(String status) async {
    await db.delete(db.meal).go();
    await db.delete(db.ingredient).go();
    await seedAddOnMeal(db, start, status: status);
  }

  Future<MealAddOnResult> add({double meat = 200, DateTime? at}) async {
    final draft = await addOnDraft(db, meat: meat);
    return withClock(
      Clock.fixed(at ?? now),
      () => container.read(recordMealAddOnUseCaseProvider).call(draft),
    );
  }

  Future<MealCompletionResult> finish({double? meat, DateTime? at}) async {
    final draft = await addOnDraft(db, meat: meat);
    final end = at ?? now.add(const Duration(minutes: 5));
    return withClock(
      Clock.fixed(end),
      () => container
          .read(completeMealUseCaseProvider)
          .call(
            draft: draft,
            choice: inferMealCompletionChoice(draft),
            endedAt: end,
          ),
    );
  }

  test(
    'a guarded new food-first start defers eCarbs and preserves the actual start time',
    () async {
      await seedWithStatus('planned');
      final occurredAt = start.subtract(const Duration(minutes: 5));
      expect(
        await db.mealDao.tryUpdateMealStatus(
          1,
          'eating-then-bolus',
          occurredAt: occurredAt,
        ),
        isTrue,
      );
      final context = (await readMealAddOnBolusContext(db, 1))!;
      expect(context.reportedExtendedCarbs, 0);
      expect(context.requestedExtendedCarbs, 0);
      expect(context.eatingStartedAt, occurredAt);
      expect(context.requestedAt, occurredAt);
      final result = await finish();
      expect(result.requiresBolus, isTrue);
      expect(result.aapsCarbs!.carbs, 42);
      expect(result.aapsCarbs!.extendedCarbs, 19);
    },
  );

  test(
    'legacy food-first recovery retains its previous eCarbs baseline through add-on and completion',
    () async {
      await db.customStatement(
        'UPDATE meal SET add_on_bolus_context=NULL WHERE id=1',
      );
      final recovered = (await reconcileMealAddOnBolusProgress(db, 1))!;
      expect(recovered.reportedExtendedCarbs, 19);
      await db.mealDao.updateMealStatus(1, 'eating-then-bolus');
      expect(
        (await readMealAddOnBolusContext(db, 1))!.reportedExtendedCarbs,
        19,
      );

      final added = await add();
      expect(added.aapsCarbs.extendedCarbs, 0);
      expect(
        (await readMealAddOnBolusContext(db, 1))!.reportedExtendedCarbs,
        19,
      );
      await acceptDeliveredMealAddOnBolus(
        db,
        1,
        testBolusWizard(
          createdAt: now.add(const Duration(seconds: 30)),
          carbs: 44,
        ),
        requestedAt: now,
      );
      final result = await finish();
      expect(result.requiresBolus, isFalse);
      expect(result.consumedExtendedCarbs, 36);
      expect(result.aapsCarbs!.carbs, 0);
      expect(result.aapsCarbs!.extendedCarbs, 17);
      expect((await db.mealDao.getMealById(1))!.status, 'summarized');
    },
  );

  test(
    'eat first requests the unbolused original meal plus only the added meatball',
    () async {
      final result = await add();
      final context = (await readMealAddOnBolusContext(db, 1))!;
      expect(result.aapsCarbs.carbs, 44);
      expect(result.aapsCarbs.extendedCarbs, 0);
      expect(context.awaitingBolus, isTrue);
      expect(context.bolusConfirmed, isFalse);
      expect(context.coveredCarbs, 0);
      expect(context.reportedExtendedCarbs, 0);
      expect(context.eatingStartedAt, start);
      final rows = await db.mealIngredientsDao.getMealIngredientsForMeal(1);
      expect(rows.map((row) => row.consumedAmount), [200, 200]);
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
    },
  );

  for (final status in ['bolused-eating', 'waited-eating']) {
    test(
      '$status add-on requests only amounts beyond the confirmed initial bolus',
      () async {
        await seedWithStatus(status);
        final result = await add();
        expect(result.aapsCarbs.carbs, 2);
        expect(result.aapsCarbs.extendedCarbs, 17);
        expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 42);
      },
    );
  }

  test(
    'linked initial calculator amount takes priority over planned quantity',
    () async {
      await seedWithStatus('bolused-eating');
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('first','aaps',?,30)",
        [start.millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, start);
      await db.mealWizardLinkDao.link(
        mealId: 1,
        localWizardId: 'first',
        relationType: 'initial',
      );
      expect((await add()).aapsCarbs.carbs, 14);
    },
  );

  test(
    'repeated pending additions do not treat the previous reported amount as bolused',
    () async {
      await add();
      final second = await add(
        meat: 300,
        at: now.add(const Duration(minutes: 1)),
      );
      expect(second.aapsCarbs.carbs, 46);
      expect(second.aapsCarbs.extendedCarbs, 0);
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 0);
    },
  );

  test(
    'calculator persisted between pending additions is reconciled before returning the second instruction',
    () async {
      await add();
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('between','aaps',?,44)",
        [now.add(const Duration(seconds: 30)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, now.add(const Duration(seconds: 30)));
      final second = await add(
        meat: 300,
        at: now.add(const Duration(minutes: 1)),
      );
      expect(second.aapsCarbs.carbs, 2);
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 44);
      expect(
        (await db.mealWizardLinkDao.forMeal(1)).single.localWizardId,
        'between',
      );
    },
  );

  test(
    'late response from the earlier pending request remains eligible only through the current generation',
    () async {
      await add();
      final secondAt = now.add(const Duration(minutes: 1));
      await add(meat: 300, at: secondAt);
      final wizard = testBolusWizard(
        createdAt: now.add(const Duration(seconds: 30)),
        carbs: 44,
      );
      expect(
        await acceptDeliveredMealAddOnBolus(db, 1, wizard, requestedAt: now),
        isNull,
      );
      final accepted = await acceptDeliveredMealAddOnBolus(
        db,
        1,
        wizard,
        requestedAt: secondAt,
      );
      expect(accepted!.requestedCarbs, 2);
      expect(accepted.awaitingBolus, isTrue);
    },
  );

  test(
    'initial calculator recorded while eating is reconciled before the first add-on',
    () async {
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('early','aaps',?,42)",
        [start.add(const Duration(minutes: 5)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, start.add(const Duration(minutes: 5)));
      final first = await add();
      expect(first.aapsCarbs.carbs, 2);
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 42);
      expect(
        (await db.mealWizardLinkDao.forMeal(1)).single.relationType,
        'initial',
      );
    },
  );

  test(
    'dismissed or other-meal calculator entries never cover the current meal',
    () async {
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('dismissed','aaps',?,42)",
        [start.add(const Duration(minutes: 5)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, start.add(const Duration(minutes: 5)));
      await db.mealWizardLinkDao.link(
        mealId: 1,
        localWizardId: 'dismissed',
        relationType: 'initial',
      );
      await db.mealWizardLinkDao.unlink(
        (await db.mealWizardLinkDao.forMeal(1)).single.id,
      );
      await db.customStatement(
        "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Other meal',1000,'summarized')",
      );
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('other-meal','aaps',?,42)",
        [start.add(const Duration(minutes: 6)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, start.add(const Duration(minutes: 6)));
      await db.mealWizardLinkDao.link(
        mealId: 2,
        localWizardId: 'other-meal',
        relationType: 'initial',
      );
      final first = await add();
      expect(first.aapsCarbs.carbs, 44);
      expect((await readMealAddOnBolusContext(db, 1))!.bolusConfirmed, isFalse);
    },
  );

  test(
    'calculator replay under a new local identity does not increase covered carbs twice',
    () async {
      await add(meat: 300);
      final wizard = testBolusWizard(
        createdAt: now.add(const Duration(seconds: 30)),
        carbs: 20,
      );
      await acceptDeliveredMealAddOnBolus(db, 1, wizard, requestedAt: now);
      expect(
        await acceptDeliveredMealAddOnBolus(
          db,
          1,
          wizard.copyWith(localId: 'mirrored-later'),
          requestedAt: now,
        ),
        isNull,
      );
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 20);
    },
  );

  test(
    'actual calculator confirmation survives reload and the next add-on only asks its delta',
    () async {
      await add();
      final accepted = await acceptDeliveredMealAddOnBolus(
        db,
        1,
        testBolusWizard(
          createdAt: now.add(const Duration(seconds: 30)),
          carbs: 44,
        ),
        requestedAt: now,
      );
      expect(accepted!.awaitingBolus, isFalse);
      expect(accepted.bolusConfirmed, isTrue);
      expect(accepted.requestedExtendedCarbs, 0);
      expect(MealAddOnBolusContext.decode(accepted.encode())!.coveredCarbs, 44);
      final next = await add(
        meat: 300,
        at: now.add(const Duration(minutes: 1)),
      );
      expect(next.aapsCarbs.carbs, 2);
      expect(next.aapsCarbs.extendedCarbs, 0);
    },
  );

  test(
    'default completion releases actual eCarbs including the add-on without repeating its bolus',
    () async {
      await add();
      await acceptDeliveredMealAddOnBolus(
        db,
        1,
        testBolusWizard(
          createdAt: now.add(const Duration(seconds: 30)),
          carbs: 44,
        ),
        requestedAt: now,
      );
      final result = await finish();
      expect(result.requiresBolus, isFalse);
      expect(result.consumedCarbs, 44);
      expect(result.consumedExtendedCarbs, 36);
      expect(result.aapsCarbs!.carbs, 0);
      expect(result.aapsCarbs!.extendedCarbs, 36);
      expect((await db.mealDao.getMealById(1))!.status, 'summarized');
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 400);
    },
  );

  test(
    'finishing before the pending bolus retains confirmed quantities and only the outstanding amount',
    () async {
      await seedWithStatus('bolused-eating');
      await add();
      final result = await finish();
      final meal = (await db.mealDao.getMealById(1))!;
      expect(result.requiresBolus, isTrue);
      expect(result.aapsCarbs!.carbs, 2);
      expect(meal.status, 'waiting-for-bolus');
      expect(meal.consumptionConfirmedEndedAt, isNotNull);
      expect((await readMealAddOnBolusContext(db, 1))!.requestedCarbs, 2);
      await acceptDeliveredMealAddOnBolus(
        db,
        1,
        testBolusWizard(
          createdAt: now.add(const Duration(minutes: 6)),
          carbs: 2,
        ),
        requestedAt: now,
      );
      await db.mealDao.tryUpdateMealStatus(1, 'eaten-bolused');
      expect(await db.mealDao.summarizeConfirmedMealAfterBolus(1), isTrue);
      expect((await db.mealDao.getMealById(1))!.addOnBolusContext, isNull);
    },
  );

  test(
    'already eaten extra meatball waits for remaining delivery without adding potatoes or reopening eating',
    () async {
      await seedWithStatus('bolused-eating');
      final result = await finish(meat: 200);
      expect(result.requiresBolus, isTrue);
      expect(result.aapsCarbs!.carbs, 2);
      expect(result.aapsCarbs!.extendedCarbs, 17);
      expect((await db.mealDao.getMealById(1))!.status, 'waiting-for-bolus');
      final pending = (await readMealAddOnBolusContext(db, 1))!;
      expect(pending.awaitingBolus, isTrue);
      expect(pending.coveredCarbs, 42);
      expect(pending.requestedCarbs, 2);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).last.consumedAmount,
        200,
      );
      expect(
        (await db.select(db.mealStatusHistory).get()).where(
          (row) => row.status == 'eating-extra',
        ),
        isEmpty,
      );
    },
  );

  test(
    'zero-carb calculator event cannot satisfy a pending ordinary bolus',
    () async {
      await add();
      expect(
        await acceptDeliveredMealAddOnBolus(
          db,
          1,
          testBolusWizard(
            createdAt: now.add(const Duration(seconds: 30)),
            carbs: 0,
          ),
          requestedAt: now,
        ),
        isNull,
      );
      expect((await readMealAddOnBolusContext(db, 1))!.awaitingBolus, isTrue);
    },
  );

  test(
    'stale calculator cannot confirm a newer request or an interrupted meal',
    () async {
      await add();
      await add(meat: 300, at: now.add(const Duration(minutes: 1)));
      final wizard = testBolusWizard(
        createdAt: now.add(const Duration(minutes: 2)),
        carbs: 46,
      );
      expect(
        await acceptDeliveredMealAddOnBolus(db, 1, wizard, requestedAt: now),
        isNull,
      );
      await db.mealDao.interruptMeal(1);
      expect(
        await acceptDeliveredMealAddOnBolus(
          db,
          1,
          wizard,
          requestedAt: now.add(const Duration(minutes: 1)),
        ),
        isNull,
      );
      expect((await db.mealDao.getMealById(1))!.addOnBolusContext, isNull);
      expect((await db.mealDao.getMealById(1))!.status, 'interrupted');
    },
  );

  test(
    'stale and overlapping add-on saves leave quantities and contexts unchanged',
    () async {
      final draft = await addOnDraft(db, meat: 200);
      await db.customStatement(
        "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Other',1000,'eating')",
      );
      await expectLater(
        container.read(recordMealAddOnUseCaseProvider).call(draft),
        throwsA(isA<MealActivationException>()),
      );
      await db.customStatement('DELETE FROM meal WHERE id=2');
      await add();
      await expectLater(
        container.read(recordMealAddOnUseCaseProvider).call(draft),
        throwsA(
          anyOf(
            isA<MealActivationException>(),
            isA<MealSummaryCannotFinishException>(),
          ),
        ),
      );
      expect((await readMealAddOnBolusContext(db, 1))!.requestedCarbs, 44);
    },
  );
}

Future<void> seedAddOnMeal(
  DatabaseImpl db,
  DateTime start, {
  String status = 'eating-then-bolus',
}) async {
  await db.customStatement(
    "INSERT INTO ingredient (id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,carbs_label_mode,nutrition_confidence) VALUES (1,'Meatball',2,10,0,20,'eu',1),(2,'Potatoes',20,0,0,2,'eu',1)",
  );
  await db.customStatement(
    "INSERT INTO meal (id,name,planned_at,status) VALUES (1,'Lunch',?,'planned')",
    [start.millisecondsSinceEpoch],
  );
  await db.customStatement(
    'INSERT INTO meal_ingredients (id,meal_id,ingredient_id,amount,quantity_confidence) VALUES (1,1,1,100,1),(2,1,2,200,1)',
  );
  await db.mealDao.updateMealStatus(1, status, occurredAt: start);
}

Future<MealSummaryDraft> addOnDraft(
  DatabaseImpl db, {
  double? meat,
  double? potatoes,
}) async {
  final meal = (await db.mealDao.getMealById(1))!;
  final rows = await db.mealIngredientsDao.getMealIngredientsForMeal(1);
  return MealSummaryDraft(
    mealId: 1,
    mealStatus: meal.status,
    itemIds: const [1, 2],
    extraItems: const [],
    itemsById: {
      for (final row in rows)
        row.id: MealSummaryItemDraft(
          name: row.id == 1 ? 'Meatball' : 'Potatoes',
          mealIngredientId: row.id,
          plannedAmount: row.amount,
          reportedAmount: row.consumedAmount ?? row.amount,
          consumedAmount:
              (row.id == 1 ? meat : potatoes) ??
              row.consumedAmount ??
              row.amount,
          amountLabel: 'g',
          consumedConfidence: 1,
          gramsPerAmount: 1,
          netCarbsPerAmount: row.id == 1 ? .02 : .2,
          carbsPerAmount: row.id == 1 ? .02 : .2,
          fatPerAmount: row.id == 1 ? .1 : 0,
          proteinPerAmount: row.id == 1 ? .2 : .02,
        ),
    },
  );
}
