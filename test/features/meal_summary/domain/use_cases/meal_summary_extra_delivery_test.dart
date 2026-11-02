import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/manual_bolus_drift_mapper.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, MealCompanion;
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/tasks/meal_monitor_test.dart'
    show testBolusWizard;
import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../foreground/utils/fake_runtime_harness.dart';

void main() {
  for (final (previousContext, anotherActiveMeal) in [
    (false, false),
    (true, false),
    (false, true),
  ]) {
    test(
      anotherActiveMeal
          ? 'summary quantity increase cannot reactivate an older meal over another active meal'
          : 'summary quantity increase waits for its extra delivery with ${previousContext ? 'completed' : 'no'} prior context',
      () async {
        final start = DateTime(2026, 11, 2, 16, 33, 12);
        final endedAt = DateTime(2026, 11, 2, 16, 33, 45, 740);
        final savedAt = DateTime(2026, 11, 2, 16, 33, 49);
        final db = DatabaseImpl(NativeDatabase.memory());
        final notifications = FakeNotificationsController();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notificationsControllerUiProvider.overrideWithValue(notifications),
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
            mealBolusDeliveryHistoryProvider.overrideWithValue((_) async => []),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        addTearDown(() async {
          harness.cancel();
          container.dispose();
          await db.close();
        });
        await db.customStatement(
          "INSERT INTO ingredient (id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,carbs_label_mode,nutrition_confidence,is_reference) VALUES (1,'Meal',15,0,0,0,'eu',1,1)",
        );
        await db.customStatement(
          "INSERT INTO meal (id,name,planned_at,status) VALUES (1,'Meal',?,'planned')",
          [start.millisecondsSinceEpoch],
        );
        await db.customStatement(
          'INSERT INTO meal_ingredients (id,meal_id,ingredient_id,amount,consumed_amount,quantity_confidence,consumed_confidence) VALUES (1,1,1,1,2,1,1)',
        );
        for (final entry in [
          ('eating-then-bolus', start),
          ('eating-extra', DateTime(2026, 11, 2, 16, 33, 16, 822)),
          ('eaten-extra', endedAt),
        ]) {
          await db.mealDao.updateMealStatus(1, entry.$1, occurredAt: entry.$2);
        }
        final initial = testBolusWizard(
          createdAt: DateTime(2026, 11, 2, 16, 33, 32, 581),
          carbs: 30,
          insulin: 43.8,
        );
        final initialDelivery = ManualBolus(
          externalId: 'initial-delivery',
          createdAt: DateTime(2026, 11, 2, 16, 33, 34, 457),
          insulin: 3,
        );
        final stored = await db.localMirrorDao.upsertBolusWizard(
          initial.toCompanion(TreatmentsSource.aaps),
        );
        await db.localMirrorDao.upsertManualBolus(
          initialDelivery.toCompanion(TreatmentsSource.aaps),
        );
        await db.mealWizardLinkDao.link(
          mealId: 1,
          localWizardId: stored.localId,
          relationType: 'initial',
        );
        final completed = MealAddOnBolusContext(
          originalStatus: 'eating-then-bolus',
          eatingStartedAt: start,
          requestedAt: start,
          coveredCarbs: 30,
          statusCoveredCarbs: 0,
          reportedExtendedCarbs: 0,
          requestedCarbs: 0,
          requestedExtendedCarbs: 0,
          awaitingBolus: false,
          bolusConfirmed: true,
          acceptedWizardKeys: [
            'local:${stored.localId}',
            'at:${initial.createdAt.millisecondsSinceEpoch}',
          ],
        );
        await (db.update(db.meal)..where((row) => row.id.equals(1))).write(
          MealCompanion(
            addOnBolusContext: Value(
              previousContext ? completed.encode() : null,
            ),
          ),
        );
        final draft = MealSummaryDraft(
          mealId: 1,
          mealStatus: 'eaten-extra',
          itemIds: const [1],
          extraItems: const [],
          itemsById: {
            1: MealSummaryItemDraft(
              name: 'Meal',
              mealIngredientId: 1,
              plannedAmount: 1,
              reportedAmount: 2,
              consumedAmount: 2.5,
              amountLabel: '100 g',
              consumedConfidence: 1,
              gramsPerAmount: 100,
              netCarbsPerAmount: 15,
              carbsPerAmount: 15,
            ),
          },
        );
        if (anotherActiveMeal) {
          await db.customStatement(
            "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Other meal',?,'bolused-eating')",
            [savedAt.millisecondsSinceEpoch],
          );
          await expectLater(
            withClock(
              Clock.fixed(savedAt),
              () => container
                  .read(finalizeMealSummaryUseCaseProvider)
                  .call(draft),
            ),
            throwsA(isA<MealSummaryCannotFinishException>()),
          );
          expect((await db.mealDao.getMealById(1))!.status, 'eaten-extra');
          expect((await db.mealDao.getMealById(2))!.status, 'bolused-eating');
          expect(
            (await db.mealIngredientsDao.getMealIngredientsForMeal(
              1,
            )).single.consumedAmount,
            2,
          );
          expect(await db.select(db.mealSnapshot).get(), isEmpty);
          expect(notifications.cancelledIds, isEmpty);
          return;
        }
        await withClock(
          Clock.fixed(savedAt),
          () => container.read(finalizeMealSummaryUseCaseProvider).call(draft),
        );
        final waiting = (await db.mealDao.getMealById(1))!;
        expect(waiting.status, 'waiting-for-bolus');
        expect(
          waiting.consumptionConfirmedEndedAt,
          endedAt.millisecondsSinceEpoch,
        );
        final pending = (await readMealAddOnBolusContext(db, 1))!;
        expect(pending.requestedCarbs, 8);
        expect(pending.coveredCarbs, 30);
        expect(pending.awaitingBolus, isTrue);
        expect(
          (await db.select(db.mealSnapshot).get()).single.totalNetCarbsG,
          37.5,
        );
        expect(await db.mealDao.summarizeConfirmedMealAfterBolus(1), isFalse);
        final extra = testBolusWizard(
          createdAt: DateTime(2026, 11, 2, 16, 33, 58, 334),
          carbs: 8,
          insulin: 17.8,
        );
        final actual = ManualBolus(
          externalId: 'extra-delivery',
          createdAt: DateTime(2026, 11, 2, 16, 34, 0, 458),
          insulin: 3,
        );
        container.read(latestBolusWizardProvider.notifier).update(extra);
        harness.dispatchEvent(TreatmentAvailableEvent<ManualBolus>(actual));
        final context = MealMonitorContext(activeMeal: waiting.toDomain());
        await withClock(
          Clock.fixed(DateTime(2026, 11, 2, 16, 34, 8)),
          () async {
            final next = await WaitForBolusExecutor().execute(
              harness.runtimeContext,
              context,
            );
            expect(next, isA<FinalizeMealExecutor>());
            await next.execute(harness.runtimeContext, context);
          },
        );
        expect((await db.mealDao.getMealById(1))!.status, 'summarized');
        expect(
          (await db.mealWizardLinkDao.forMeal(
            1,
          )).map((link) => link.relationType),
          ['initial', 'continuation'],
        );
        expect(
          (await db.select(db.manualBolus).get()).map((bolus) => bolus.insulin),
          [3, 3],
        );
      },
    );
  }
}
