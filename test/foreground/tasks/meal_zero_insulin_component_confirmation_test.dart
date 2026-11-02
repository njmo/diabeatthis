import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/common/meal/meal_bolus_coverage.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/meal_add_on_bolus_waiter.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meal_summary/domain/use_cases/complete_meal_use_case_test.dart'
    show seedCompletionMeal;
import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  final start = DateTime(2026, 11, 2, 17, 24);
  final wizardAt = DateTime(2026, 11, 2, 17, 25, 12);
  late DatabaseImpl db;
  late LocalMirrorWriter writer;
  late ProviderContainer container;
  late FakeRuntimeHarness harness;

  ProviderContainer createContainer({List<Treatment> history = const []}) =>
      ProviderContainer(
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
          notificationsControllerForegroundProvider.overrideWithValue(
            FakeNotificationsController(),
          ),
          mealBolusDeliveryHistoryProvider.overrideWithValue(
            (_) async => history,
          ),
        ],
      );

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    writer = LocalMirrorWriter(db.localMirrorDao);
    container = createContainer();
    harness = FakeRuntimeHarness(container: container);
    await seedCompletionMeal(db);
    await db.customUpdate(
      'UPDATE meal_ingredients SET amount = 60 WHERE id = 1',
    );
    await db.mealDao.updateMealStatus(
      1,
      'eating-then-bolus',
      occurredAt: start,
    );
    await reconcileMealAddOnBolusProgress(db, 1);
    expect((await readMealAddOnBolusContext(db, 1))!.requestedCarbs, 12);
    container.read(databaseProvider);
  });

  tearDown(() async {
    harness.cancel();
    container.dispose();
    await db.close();
  });

  Treat component({bool leading = false}) => Treat(
    externalId: 'submitted-12g',
    createdAt: wizardAt.add(Duration(milliseconds: leading ? -1 : 830)),
    carbs: 12,
  );

  Future<void> ingest(Iterable<Treatment> records) async {
    final accepted = await writer.mirrorTreatments(
      records,
      TreatmentsSource.aaps,
    );
    for (final treatment in accepted) {
      TreatmentEventDispatcher().dispatch(
        container: container,
        emitEvent: harness.dispatchEvent,
        treatment: treatment,
      );
    }
  }

  Future<void> expectCompletedWithoutInsulin() async {
    final context = (await readMealAddOnBolusContext(db, 1))!;
    expect(context.awaitingBolus, isFalse);
    expect(context.requestedCarbs, 0);
    expect(context.coveredCarbs, 12);
    expect((await readMealBolusCoverage(db, 1)).carbs, 12);
    expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));
    expect(await db.select(db.manualBolus).get(), isEmpty);
    expect(await db.select(db.treat).get(), isEmpty);
    expect(
      (await db.select(db.bolusWizard).get()).single.carbohydrateComponent,
      isNotNull,
    );
  }

  for (final carbsFirst in [false, true]) {
    test(
      'separate zero-insulin submission survives restart with carbsFirst=$carbsFirst',
      () async {
        final wizard = testBolusWizard(
          createdAt: wizardAt,
          carbs: 12,
          insulin: 0,
        );
        final records = <Treatment>[wizard, component()];
        for (final record in carbsFirst ? records.reversed : records) {
          await writer.mirrorTreatments([record], TreatmentsSource.aaps);
        }
        // The component is persisted inside the calculator, without invented insulin.
        expect(
          (await db.select(db.bolusWizard).get()).single.carbohydrateComponent,
          isNotNull,
        );
        expect(await db.select(db.manualBolus).get(), isEmpty);
        harness.cancel();
        container.dispose();
        container = createContainer();
        harness = FakeRuntimeHarness(container: container);
        container.read(databaseProvider);
        final recovered = await reconcileMealAddOnBolusProgress(db, 1);
        expect(recovered!.awaitingBolus, isFalse);
        final completed = await withClock(
          Clock.fixed(wizardAt.add(const Duration(minutes: 1))),
          () async => const MealAddOnBolusWaiter()(
            harness.runtimeContext,
            MealMonitorContext(
              activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
            ),
            remindImmediately: false,
          ),
        );
        expect(completed, isTrue);
        await expectCompletedWithoutInsulin();
        await writer.mirrorTreatments(records, TreatmentsSource.aaps);
        await reconcileMealAddOnBolusProgress(db, 1);
        await expectCompletedWithoutInsulin();
      },
    );
  }

  test(
    'live zero calculator stays pending until its separately arriving carbs confirm it',
    () async {
      await withClock(Clock.fixed(wizardAt), () async {
        bool? completed;
        final running =
            const MealAddOnBolusWaiter()(
                  harness.runtimeContext,
                  MealMonitorContext(
                    activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
                  ),
                  remindImmediately: false,
                )
                .then((value) {
                  completed = value;
                })
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                });
        try {
          await pumpEventQueue(times: 100);
          await ingest([
            testBolusWizard(createdAt: wizardAt, carbs: 12, insulin: 0),
          ]);
          await pumpEventQueue(times: 100);
          expect(completed, isNull);
          expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 0);
          expect(await db.mealWizardLinkDao.forMeal(1), isEmpty);
          await ingest([component()]);
          await pumpEventQueue(times: 200);
          expect(completed, isTrue);
          await expectCompletedWithoutInsulin();
        } finally {
          harness.cancel();
          await running;
        }
      });
    },
  );

  test(
    'configured history can confirm and persist a zero-insulin component missing locally',
    () async {
      final wizard = testBolusWizard(
        createdAt: wizardAt,
        carbs: 12,
        insulin: 0,
      );
      await writer.mirrorTreatments([wizard], TreatmentsSource.aaps);
      harness.cancel();
      container.dispose();
      container = createContainer(history: [wizard, component()]);
      harness = FakeRuntimeHarness(container: container);
      container.read(databaseProvider);
      await withClock(Clock.fixed(wizardAt), () async {
        bool? completed;
        final running =
            const MealAddOnBolusWaiter()(
                  harness.runtimeContext,
                  MealMonitorContext(
                    activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
                  ),
                  remindImmediately: false,
                )
                .then((value) {
                  completed = value;
                })
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                });
        try {
          await pumpEventQueue(times: 200);
          expect(completed, isTrue);
          await expectCompletedWithoutInsulin();
        } finally {
          harness.cancel();
          await running;
        }
      });
    },
  );

  for (final insulin in <double?>[null, 3.15]) {
    test(
      'confirmed carbs do not replace missing or positive insulin recommendation $insulin',
      () async {
        final base = testBolusWizard(
          createdAt: wizardAt,
          carbs: 12,
          insulin: 0,
        );
        final wizard = base.copyWith(
          calculatorResult: base.calculatorResult!.copyWith(
            totalInsulin: insulin,
          ),
        );
        await writer.mirrorTreatments([
          component(leading: true),
          wizard,
        ], TreatmentsSource.aaps);
        expect(
          (await db.select(db.bolusWizard).get()).single.carbohydrateComponent,
          isNotNull,
        );
        final pending = (await reconcileMealAddOnBolusProgress(db, 1))!;
        expect(pending.awaitingBolus, isTrue);
        expect(pending.coveredCarbs, 0);
        expect(await db.mealWizardLinkDao.forMeal(1), isEmpty);
        expect(await db.select(db.manualBolus).get(), isEmpty);
      },
    );
  }

  test(
    'a zero recommendation corrected to positive still needs actual delivery',
    () async {
      final zero = testBolusWizard(createdAt: wizardAt, carbs: 12, insulin: 0);
      await writer.mirrorTreatments([
        component(leading: true),
        zero,
      ], TreatmentsSource.aaps);
      final corrected = zero.copyWith(
        calculatorResult: zero.calculatorResult!.copyWith(totalInsulin: 3.15),
      );
      await writer.mirrorTreatments([corrected], TreatmentsSource.aaps);
      expect(
        (await reconcileMealAddOnBolusProgress(db, 1))!.awaitingBolus,
        isTrue,
      );
      expect(await db.mealWizardLinkDao.forMeal(1), isEmpty);
      await writer.mirrorTreatments([
        ManualBolus(
          externalId: 'actual-positive-delivery',
          createdAt: wizardAt.add(const Duration(milliseconds: 830)),
          insulin: 3,
        ),
      ], TreatmentsSource.aaps);
      final confirmed = (await reconcileMealAddOnBolusProgress(db, 1))!;
      expect(confirmed.awaitingBolus, isFalse);
      expect(confirmed.coveredCarbs, 12);
      expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));
      expect((await db.select(db.manualBolus).get()).single.insulin, 3);
    },
  );

  test(
    'invalidated actual delivery prevents zero fallback after restart and carbohydrate replay',
    () async {
      final wizard = testBolusWizard(
        createdAt: wizardAt,
        carbs: 12,
        insulin: 0,
      );
      final originalDelivery = ManualBolus(
        externalId: 'invalidated-actual',
        createdAt: wizardAt.add(const Duration(milliseconds: 830)),
        insulin: 3,
      );
      await writer.mirrorTreatments([
        wizard,
        originalDelivery,
        component(),
      ], TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        originalDelivery.copyWith(isValid: false),
      ], TreatmentsSource.aaps);
      expect(await db.select(db.manualBolus).get(), isEmpty);
      harness.cancel();
      container.dispose();
      container = createContainer();
      harness = FakeRuntimeHarness(container: container);
      container.read(databaseProvider);

      await ingest([wizard, component()]);
      final pending = (await reconcileMealAddOnBolusProgress(db, 1))!;
      expect(pending.awaitingBolus, isTrue);
      expect(pending.coveredCarbs, 0);
      expect(await db.mealWizardLinkDao.forMeal(1), isEmpty);

      await writer.mirrorTreatments([
        component().copyWith(isValid: false),
      ], TreatmentsSource.aaps);
      await writer.mirrorTreatments([component()], TreatmentsSource.aaps);
      harness.cancel();
      container.dispose();
      container = createContainer();
      harness = FakeRuntimeHarness(container: container);
      container.read(databaseProvider);
      expect(
        (await reconcileMealAddOnBolusProgress(db, 1))!.awaitingBolus,
        isTrue,
      );
      harness.dispatchEvent(TreatmentAvailableEvent(wizard));
      expect(
        container
            .read(calculatorSubmissionsProvider)
            .single
            .wizard
            .hasUnresolvedDelivery,
        isFalse,
      );

      await withClock(
        Clock.fixed(wizardAt.add(const Duration(seconds: 2))),
        () async {
          bool? completed;
          final running =
              const MealAddOnBolusWaiter()(
                    harness.runtimeContext,
                    MealMonitorContext(
                      activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
                    ),
                    remindImmediately: false,
                  )
                  .then((value) {
                    completed = value;
                  })
                  .catchError((Object error) {
                    if (error is! TaskCancelledException) throw error;
                  });
          try {
            await pumpEventQueue(times: 100);
            expect(completed, isNull);
            await ingest([component()]);
            await pumpEventQueue(times: 100);
            expect(completed, isNull);
            expect(await db.select(db.manualBolus).get(), isEmpty);
            await ingest([
              originalDelivery.copyWith(
                externalId: 'replacement-actual',
                createdAt: wizardAt.add(const Duration(milliseconds: 1600)),
              ),
            ]);
            await pumpEventQueue(times: 200);
            expect(completed, isTrue);
            expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 12);
            expect((await readMealBolusCoverage(db, 1)).carbs, 12);
            expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));
            expect((await db.select(db.manualBolus).get()).single.insulin, 3);
            expect(await db.select(db.treat).get(), isEmpty);
          } finally {
            harness.cancel();
            await running;
          }
        },
      );
    },
  );
}
