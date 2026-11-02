import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/common/meal/meal_bolus_coverage.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/manual_bolus_drift_mapper.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/tasks/meal_monitor_test.dart'
    show testBolusWizard;
import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../foreground/utils/fake_runtime_harness.dart';
import 'complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;

void main() {
  final startedAt = DateTime(2026, 11, 2, 16, 33, 12);
  final firstWizardAt = DateTime(2026, 11, 2, 16, 33, 32, 581);
  final endedAt = DateTime(2026, 11, 2, 16, 33, 45, 740);
  final savedAt = DateTime(2026, 11, 2, 16, 33, 49);
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
        notificationsControllerForegroundProvider.overrideWithValue(
          FakeNotificationsController(),
        ),
      ],
    );
    await seedCompletionMeal(db);
    await db.customUpdate(
      'UPDATE ingredient SET carbs_per_100g = 15 WHERE id = 1',
    );
    await db.customUpdate(
      'UPDATE meal_ingredients SET consumed_amount = 200 WHERE id = 1',
    );
    await db.mealDao.updateMealStatus(
      1,
      'eating-then-bolus',
      occurredAt: startedAt,
    );
    final wizard = testBolusWizard(
      createdAt: firstWizardAt,
      carbs: 30,
      insulin: 30,
    );
    final stored = await db.localMirrorDao.upsertBolusWizard(
      wizard.toCompanion(TreatmentsSource.aaps),
    );
    await db.localMirrorDao.upsertManualBolus(
      domain.ManualBolus(
        externalId: 'initial-delivery',
        createdAt: firstWizardAt.add(const Duration(milliseconds: 830)),
        insulin: 3,
      ).toCompanion(TreatmentsSource.aaps),
    );
    await db.mealWizardLinkDao.link(
      mealId: 1,
      localWizardId: stored.localId,
      relationType: 'initial',
    );
    final context = MealAddOnBolusContext(
      originalStatus: 'eating-then-bolus',
      eatingStartedAt: startedAt,
      requestedAt: startedAt,
      coveredCarbs: 30,
      statusCoveredCarbs: 0,
      reportedExtendedCarbs: 0,
      requestedCarbs: 0,
      requestedExtendedCarbs: 0,
      awaitingBolus: false,
      bolusConfirmed: true,
      acceptedWizardKeys: [
        'local:${stored.localId}',
        'at:${firstWizardAt.millisecondsSinceEpoch}',
      ],
    );
    await (db.update(db.meal)..where((row) => row.id.equals(1))).write(
      MealCompanion(addOnBolusContext: Value(context.encode())),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'an ended meal cannot reopen for extra insulin while another meal is active',
    () async {
      await db.mealDao.updateMealStatus(1, 'eaten-extra', occurredAt: endedAt);
      await db.customInsert(
        "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Dinner',1793628000000,'eating')",
      );
      await expectLater(
        withClock(
          Clock.fixed(savedAt),
          () => container
              .read(completeMealUseCaseProvider)
              .call(
                draft: completionDraft(
                  status: 'eaten-extra',
                  reported: 200,
                  consumed: 250,
                ),
                choice: MealCompletionChoice.more,
                endedAt: endedAt,
              ),
        ),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );
      expect((await db.mealDao.getMealById(1))!.status, 'eaten-extra');
      expect((await db.mealDao.getMealById(2))!.status, 'eating');
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        200,
      );
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
      expect((await readMealAddOnBolusContext(db, 1))!.awaitingBolus, isFalse);
    },
  );

  for (final status in ['eaten-extra', 'eaten-bolused']) {
    test(
      '$status keeps newly uncovered 8g pending until actual delivery',
      () async {
        if (status == 'eaten-extra') {
          await db.mealDao.updateMealStatus(
            1,
            'eating-extra',
            occurredAt: startedAt.add(const Duration(seconds: 4)),
          );
        } else {
          await db.mealDao.updateMealStatus(
            1,
            'waiting-for-bolus',
            occurredAt: endedAt,
          );
        }
        await db.mealDao.updateMealStatus(1, status, occurredAt: endedAt);
        final previous = (await readMealAddOnBolusContext(db, 1))!;
        expect(previous.awaitingBolus, isFalse);
        expect(
          (await readMealBolusCoverage(db, 1, context: previous)).carbs,
          30,
        );

        final result = await withClock(
          Clock.fixed(savedAt),
          () => container
              .read(completeMealUseCaseProvider)
              .call(
                draft: completionDraft(
                  status: status,
                  reported: 200,
                  consumed: 250,
                ),
                choice: MealCompletionChoice.more,
                endedAt: endedAt,
              ),
        );

        expect(result.requiresBolus, isTrue);
        expect(result.aapsCarbs!.carbs, 8);
        final meal = (await db.mealDao.getMealById(1))!;
        expect(meal.status, 'waiting-for-bolus');
        expect(
          meal.consumptionConfirmedEndedAt,
          endedAt.millisecondsSinceEpoch,
        );
        final pending = (await readMealAddOnBolusContext(db, 1))!;
        expect(pending.coveredCarbs, 30);
        expect(pending.requestedCarbs, 8);
        expect(pending.awaitingBolus, isTrue);
        expect(pending.acceptedWizardKeys, previous.acceptedWizardKeys);
        expect(
          (await db.select(db.mealSnapshot).get()).single.totalNetCarbsG,
          37.5,
        );
        final history = await db.select(db.mealStatusHistory).get();
        expect(history.where((row) => row.status == 'summarized'), isEmpty);
        expect(
          history
              .singleWhere((row) => row.status == 'waiting-for-bolus')
              .createdAt,
          endedAt.millisecondsSinceEpoch,
        );
        expect(
          history.singleWhere((row) => row.status == status).createdAt,
          endedAt.millisecondsSinceEpoch,
        );

        final extraWizard = testBolusWizard(
          createdAt: DateTime(2026, 11, 2, 16, 33, 58, 334),
          carbs: 8,
          insulin: 8,
        );
        await db.localMirrorDao.upsertBolusWizard(
          extraWizard.toCompanion(TreatmentsSource.aaps),
        );
        final unconfirmed = (await reconcileMealAddOnBolusProgress(db, 1))!;
        expect(unconfirmed.awaitingBolus, isTrue);
        expect(unconfirmed.coveredCarbs, 30);
        expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));

        await db.localMirrorDao.upsertManualBolus(
          domain.ManualBolus(
            externalId: 'extra-delivery',
            createdAt: extraWizard.createdAt.add(
              const Duration(milliseconds: 830),
            ),
            insulin: 3,
          ).toCompanion(TreatmentsSource.aaps),
        );
        final confirmed = (await reconcileMealAddOnBolusProgress(db, 1))!;
        expect(confirmed.awaitingBolus, isFalse);
        expect(confirmed.coveredCarbs, 38);
        expect(
          (await db.mealWizardLinkDao.forMeal(
            1,
          )).map((link) => link.relationType),
          ['initial', 'continuation'],
        );
        final harness = FakeRuntimeHarness(container: container);
        try {
          await withClock(
            Clock.fixed(DateTime(2026, 11, 2, 16, 34, 8)),
            () async {
              final context = MealMonitorContext(
                activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
              );
              final next = await WaitForBolusExecutor(
                remindImmediately: false,
              ).execute(harness.runtimeContext, context);
              expect(next, isA<FinalizeMealExecutor>());
              expect(
                (await db.mealDao.getMealById(1))!.status,
                'eaten-bolused',
              );
              await next.execute(harness.runtimeContext, context);
              expect((await db.mealDao.getMealById(1))!.status, 'summarized');
              expect(await db.mealWizardLinkDao.forMeal(1), hasLength(2));
            },
          );
        } finally {
          harness.cancel();
        }
      },
    );
  }
}
