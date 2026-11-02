import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/manual_bolus_drift_mapper.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/meal_add_on_bolus_waiter.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meal_summary/domain/use_cases/record_meal_add_on_use_case_test.dart'
    show addOnDraft, seedAddOnMeal;
import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  final start = DateTime(2026, 11, 2, 12);
  final requestedAt = start.add(const Duration(minutes: 10));
  late DateTime now;
  late DatabaseImpl db;
  late ProviderContainer container;
  late FakeRuntimeHarness harness;

  setUp(() async {
    now = requestedAt;
    db = DatabaseImpl(NativeDatabase.memory());
    final notifications = FakeNotificationsController();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dataSourceConfigProvider.overrideWithValue(
          const AsyncData(
            DataSourceConfig(
              bgSource: BgSource.cloud,
              treatmentsSource: TreatmentsSource.aaps,
              pumpStatusSource: PumpStatusSource.cloud,
              historySource: HistorySource.local,
              mirrorToLocal: true,
            ),
          ),
        ),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
        mealBolusDeliveryHistoryProvider.overrideWithValue((_) async => []),
      ],
    );
    harness = FakeRuntimeHarness(container: container);
    await seedAddOnMeal(db, start);
    final draft = await addOnDraft(db, meat: 500);
    await withClock(
      Clock.fixed(requestedAt),
      () => container.read(recordMealAddOnUseCaseProvider).call(draft),
    );
    expect((await readMealAddOnBolusContext(db, 1))!.requestedCarbs, 50);
  });

  tearDown(() async {
    harness.cancel();
    container.dispose();
    await db.close();
  });

  test(
    'later delivered submissions replace an undelivered calculator and cover the add-on in parts',
    () async {
      await withClock(Clock(() => now), () async {
        final context = MealMonitorContext(
          activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
        );
        bool? finished;
        final running =
            const MealAddOnBolusWaiter()(
                  harness.runtimeContext,
                  context,
                  remindImmediately: false,
                )
                .then((value) {
                  finished = value;
                })
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                });
        try {
          await pumpEventQueue(times: 100);
          final zero = testBolusWizard(
            createdAt: requestedAt.add(const Duration(minutes: 1)),
            carbs: 50,
            insulin: 0,
            nightscoutObjectId: 'undelivered',
          );
          now = zero.createdAt;
          harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(zero));
          await pumpEventQueue(times: 100);
          expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 0);
          expect(await db.mealWizardLinkDao.forMeal(1), isEmpty);
          expect(finished, isNull);

          now = requestedAt.add(const Duration(minutes: 23));
          harness.dispatchTick(now);
          final first = testBolusWizard(
            createdAt: now,
            carbs: 48,
            insulin: 44.7,
            nightscoutObjectId: 'first-delivered',
          );
          harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(first));
          await pumpEventQueue(times: 100);
          expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 0);
          now = deliveryFor(first).createdAt;
          harness.dispatchEvent(
            TreatmentAvailableEvent<ManualBolus>(deliveryFor(first)),
          );
          await pumpEventQueue(times: 200);
          final partial = (await readMealAddOnBolusContext(db, 1))!;
          expect(partial.coveredCarbs, 48);
          expect(partial.requestedCarbs, 2);
          expect(partial.awaitingBolus, isTrue);
          expect(finished, isNull);

          now = now.add(const Duration(minutes: 1));
          final second = testBolusWizard(
            createdAt: now,
            carbs: 2,
            insulin: 1,
            nightscoutObjectId: 'second-delivered',
          );
          harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(second));
          now = deliveryFor(second).createdAt;
          harness.dispatchEvent(
            TreatmentAvailableEvent<ManualBolus>(deliveryFor(second)),
          );
          await pumpEventQueue(times: 200);
          final complete = (await readMealAddOnBolusContext(db, 1))!;
          expect(complete.coveredCarbs, 50);
          expect(complete.requestedCarbs, 0);
          expect(complete.awaitingBolus, isFalse);
          expect(finished, isTrue);
          final links = await db.mealWizardLinkDao.forMeal(1);
          expect(links.map((link) => link.relationType), [
            'initial',
            'continuation',
          ]);
          final linkedWizardIds = links
              .map((link) => link.localWizardId)
              .toSet();
          final saved = await db.select(db.bolusWizard).get();
          expect(
            saved
                .where((wizard) => linkedWizardIds.contains(wizard.localId))
                .map((wizard) => wizard.nightscoutId),
            unorderedEquals(['first-delivered', 'second-delivered']),
          );
          expect(
            (await db.select(db.manualBolus).get()).map(
              (bolus) => bolus.insulin,
            ),
            [3, 3],
          );
        } finally {
          harness.cancel();
          await running;
        }
      });
    },
  );

  test(
    'a later delivered calculator assigned to another meal cannot replace the pending one',
    () async {
      await withClock(Clock(() => now), () async {
        final context = MealMonitorContext(
          activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
        );
        bool? finished;
        final running =
            const MealAddOnBolusWaiter()(
                  harness.runtimeContext,
                  context,
                  remindImmediately: false,
                )
                .then((value) {
                  finished = value;
                })
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                });
        try {
          await pumpEventQueue(times: 100);
          final zero = testBolusWizard(
            createdAt: requestedAt.add(const Duration(minutes: 1)),
            carbs: 50,
            insulin: 0,
            nightscoutObjectId: 'undelivered',
          );
          now = zero.createdAt;
          harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(zero));
          await pumpEventQueue(times: 100);

          final other = testBolusWizard(
            createdAt: requestedAt.add(const Duration(minutes: 23)),
            carbs: 50,
            insulin: 1,
            nightscoutObjectId: 'other-meal-delivered',
          );
          await db.customStatement(
            "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Other meal',?,'summarized')",
            [other.createdAt.millisecondsSinceEpoch],
          );
          final savedOther = await db.localMirrorDao.upsertBolusWizard(
            other.toCompanion(TreatmentsSource.aaps),
          );
          await db.localMirrorDao.upsertManualBolus(
            deliveryFor(other).toCompanion(TreatmentsSource.aaps),
          );
          await db.mealWizardLinkDao.link(
            mealId: 2,
            localWizardId: savedOther.localId,
            relationType: 'initial',
          );
          now = deliveryFor(other).createdAt;
          harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(other));
          harness.dispatchEvent(
            TreatmentAvailableEvent<ManualBolus>(deliveryFor(other)),
          );
          await pumpEventQueue(times: 200);
          expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 0);
          expect(await db.mealWizardLinkDao.forMeal(1), isEmpty);
          expect(
            (await db.mealWizardLinkDao.forMeal(2)).single.localWizardId,
            savedOther.localId,
          );
          expect(finished, isNull);

          final eligible = testBolusWizard(
            createdAt: requestedAt.add(const Duration(minutes: 24)),
            carbs: 50,
            insulin: 1,
            nightscoutObjectId: 'eligible-delivered',
          );
          now = deliveryFor(eligible).createdAt;
          harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(eligible));
          harness.dispatchEvent(
            TreatmentAvailableEvent<ManualBolus>(deliveryFor(eligible)),
          );
          await pumpEventQueue(times: 200);
          expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 50);
          expect(finished, isTrue);
          final accepted = (await db.mealWizardLinkDao.forMeal(1)).single;
          final saved = await db.select(db.bolusWizard).get();
          expect(
            saved
                .singleWhere(
                  (wizard) => wizard.localId == accepted.localWizardId,
                )
                .nightscoutId,
            'eligible-delivered',
          );
          expect(
            (await db.mealWizardLinkDao.forMeal(2)).single.localWizardId,
            savedOther.localId,
          );
        } finally {
          harness.cancel();
          await running;
        }
      });
    },
  );

  test(
    'cold add-on recovery ignores an undelivered calculator before two delivered submissions',
    () async {
      final zero = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 1)),
        carbs: 50,
        insulin: 0,
        nightscoutObjectId: 'undelivered',
      );
      final first = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 23)),
        carbs: 48,
        insulin: 44.7,
        nightscoutObjectId: 'first-delivered',
      );
      final second = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 24)),
        carbs: 2,
        insulin: 1,
        nightscoutObjectId: 'second-delivered',
      );
      for (final wizard in [zero, first, second]) {
        await db.localMirrorDao.upsertBolusWizard(
          wizard.toCompanion(TreatmentsSource.aaps),
        );
      }
      for (final wizard in [first, second]) {
        await db.localMirrorDao.upsertManualBolus(
          deliveryFor(wizard).toCompanion(TreatmentsSource.aaps),
        );
      }
      now = requestedAt.add(const Duration(minutes: 25));
      final result = await withClock(
        Clock(() => now),
        () async => const MealAddOnBolusWaiter()(
          harness.runtimeContext,
          MealMonitorContext(
            activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
          ),
          remindImmediately: false,
        ),
      );
      expect(result, isTrue);
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 50);
      final links = await db.mealWizardLinkDao.forMeal(1);
      expect(links.map((link) => link.relationType), [
        'initial',
        'continuation',
      ]);
      final saved = await db.select(db.bolusWizard).get();
      final zeroId = saved
          .singleWhere((wizard) => wizard.nightscoutId == 'undelivered')
          .localId;
      expect(links.map((link) => link.localWizardId), isNot(contains(zeroId)));
    },
  );
}

ManualBolus deliveryFor(BolusWizard wizard) => ManualBolus(
  externalId: 'delivery-${wizard.nightscoutObjectId}',
  createdAt: wizard.createdAt.add(const Duration(milliseconds: 2400)),
  insulin: 3,
);
