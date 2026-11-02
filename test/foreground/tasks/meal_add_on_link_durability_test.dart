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
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_wizard_recorder_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
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
  late DatabaseImpl db;
  late ProviderContainer container;
  late FakeRuntimeHarness harness;

  ManualBolus actual(BolusWizard wizard) => ManualBolus(
    externalId: 'actual-${wizard.createdAt.millisecondsSinceEpoch}',
    createdAt: wizard.createdAt.add(const Duration(seconds: 2)),
    insulin: 3,
  );

  setUp(() async {
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
              mirrorToLocal: false,
            ),
          ),
        ),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
        mealBolusDeliveryHistoryProvider.overrideWithValue((_) async => []),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (ref) async => const ExtendedCarbsScheduleSettings.defaults(),
        ),
        mealWizardRecorderProvider.overrideWithValue(
          (_, _, _) async => throw StateError('recorder unavailable'),
        ),
      ],
    );
    harness = FakeRuntimeHarness(container: container);
    await seedAddOnMeal(db, start, status: 'bolused-eating');
    final initial = testBolusWizard(createdAt: start, carbs: 42, insulin: 3);
    final stored = await db.localMirrorDao.upsertBolusWizard(
      initial.toCompanion(TreatmentsSource.aaps),
    );
    await db.localMirrorDao.upsertManualBolus(
      actual(initial).toCompanion(TreatmentsSource.aaps),
    );
    await db.mealWizardLinkDao.link(
      mealId: 1,
      localWizardId: stored.localId,
      relationType: 'initial',
    );
    final draft = await addOnDraft(db, meat: 200);
    await withClock(
      Clock.fixed(requestedAt),
      () => container.read(recordMealAddOnUseCaseProvider).call(draft),
    );
    expect((await readMealAddOnBolusContext(db, 1))!.requestedCarbs, 2);
  });

  tearDown(() async {
    harness.cancel();
    container.dispose();
    await db.close();
  });

  Future<MealMonitorContext> context() async => MealMonitorContext(
    activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
  );

  test(
    'accepted add-on remains linked after recorder failure and monitor restart with mirroring disabled',
    () async {
      final addon = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 1)),
        carbs: 2,
        insulin: 17.8,
      );
      harness.dispatchEvent(
        TreatmentAvailableEvent<ManualBolus>(actual(addon)),
      );
      container.read(latestBolusWizardProvider.notifier).update(addon);
      final completed = await withClock(
        Clock.fixed(addon.createdAt.add(const Duration(seconds: 10))),
        () async => const MealAddOnBolusWaiter()(
          harness.runtimeContext,
          await context(),
          remindImmediately: false,
        ),
      );
      expect(completed, isTrue);
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 44);
      container.invalidate(calculatorSubmissionsProvider);
      container.invalidate(latestBolusWizardProvider);
      expect(
        await const MealAddOnBolusWaiter()(
          harness.runtimeContext,
          await context(),
          remindImmediately: false,
        ),
        isTrue,
      );
      final links = await db.mealWizardLinkDao.forMeal(1);
      expect(links.map((link) => link.relationType), [
        'initial',
        'continuation',
      ]);
      final saved = await db.localMirrorDao.getBolusWizardsBetween(
        addon.createdAt,
        addon.createdAt,
      );
      expect(links.last.localWizardId, saved.single.localId);
      expect(
        (await db.select(db.manualBolus).get()).map((bolus) => bolus.insulin),
        [3, 3],
      );
    },
  );

  test(
    'accepting delivered add-on and its Day relation is one durable operation',
    () async {
      final addon = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 1)),
        carbs: 2,
        insulin: 17.8,
      );
      final stored = await db.localMirrorDao.upsertBolusWizard(
        addon.toCompanion(TreatmentsSource.aaps),
      );
      await db.localMirrorDao.upsertManualBolus(
        actual(addon).toCompanion(TreatmentsSource.aaps),
      );
      final accepted = await acceptMealAddOnBolus(
        db,
        1,
        addon,
        requestedAt: requestedAt,
      );
      expect(accepted!.awaitingBolus, isFalse);
      // A process may stop here before any separate foreground recorder runs.
      final recovered = await reconcileMealAddOnBolusProgress(db, 1);
      expect(recovered!.coveredCarbs, 44);
      final links = await db.mealWizardLinkDao.forMeal(1);
      expect(links.map((link) => link.relationType), [
        'initial',
        'continuation',
      ]);
      expect(links.last.localWizardId, stored.localId);
    },
  );

  test(
    'a failed relation write rolls back coverage while retaining recorded evidence',
    () async {
      final addon = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 1)),
        carbs: 2,
        insulin: 17.8,
      );
      await db.localMirrorDao.upsertBolusWizard(
        addon.toCompanion(TreatmentsSource.aaps),
      );
      await db.localMirrorDao.upsertManualBolus(
        actual(addon).toCompanion(TreatmentsSource.aaps),
      );
      await db.customStatement('''
      CREATE TRIGGER reject_add_on_link BEFORE INSERT ON meal_wizard_link
      WHEN NEW.relation_type = 'continuation'
      BEGIN SELECT RAISE(ABORT, 'relation unavailable'); END
    ''');
      await expectLater(
        acceptMealAddOnBolus(db, 1, addon, requestedAt: requestedAt),
        throwsA(isA<Exception>()),
      );
      final pending = (await readMealAddOnBolusContext(db, 1))!;
      expect(pending.coveredCarbs, 42);
      expect(pending.requestedCarbs, 2);
      expect(pending.awaitingBolus, isTrue);
      expect(pending.acceptedWizardKeys, isEmpty);
      expect(
        await db.localMirrorDao.getBolusWizardsBetween(
          addon.createdAt,
          addon.createdAt,
        ),
        hasLength(1),
      );
      expect(
        await db.localMirrorDao.getManualBolusesBetween(
          actual(addon).createdAt,
          actual(addon).createdAt,
        ),
        hasLength(1),
      );
      expect(
        (await db.mealWizardLinkDao.forMeal(
          1,
        )).map((link) => link.relationType),
        ['initial'],
      );
    },
  );
  for (final removed in ['delivery', 'wizard']) {
    test(
      'acceptance cannot resurrect an invalidated $removed after the gate',
      () async {
        final addon = testBolusWizard(
          createdAt: requestedAt.add(const Duration(minutes: 1)),
          carbs: 2,
          insulin: 17.8,
        );
        await db.localMirrorDao.upsertBolusWizard(
          addon.toCompanion(TreatmentsSource.aaps),
        );
        await db.localMirrorDao.upsertManualBolus(
          actual(addon).toCompanion(TreatmentsSource.aaps),
        );
        if (removed == 'delivery') {
          await db.localMirrorDao.deleteManualBolusByCreatedAt(
            actual(addon).createdAt,
          );
        } else {
          await db.localMirrorDao.deleteBolusWizard(
            addon.toCompanion(TreatmentsSource.aaps),
          );
        }
        expect(
          await acceptMealAddOnBolus(db, 1, addon, requestedAt: requestedAt),
          isNull,
        );
        final pending = (await readMealAddOnBolusContext(db, 1))!;
        expect(pending.coveredCarbs, 42);
        expect(pending.awaitingBolus, isTrue);
        expect(pending.acceptedWizardKeys, isEmpty);
        expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));
        if (removed == 'delivery') {
          expect(
            await db.localMirrorDao.getManualBolusesBetween(
              actual(addon).createdAt,
              actual(addon).createdAt,
            ),
            isEmpty,
          );
        } else {
          expect(
            await db.localMirrorDao.getBolusWizardsBetween(
              addon.createdAt,
              addon.createdAt,
            ),
            isEmpty,
          );
        }
      },
    );
  }

  test(
    'changed stored carbohydrate amount is not credited from stale calculator',
    () async {
      final addon = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 1)),
        carbs: 2,
        insulin: 17.8,
      );
      await db.localMirrorDao.upsertBolusWizard(
        addon
            .copyWith(
              calculatorResult: addon.calculatorResult!.copyWith(carbs: 1),
            )
            .toCompanion(TreatmentsSource.aaps),
      );
      await db.localMirrorDao.upsertManualBolus(
        actual(addon).toCompanion(TreatmentsSource.aaps),
      );
      expect(
        await acceptMealAddOnBolus(db, 1, addon, requestedAt: requestedAt),
        isNull,
      );
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 42);
      expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));
      expect(
        (await db.localMirrorDao.getBolusWizardsBetween(
          addon.createdAt,
          addon.createdAt,
        )).single.carbs,
        1,
      );
    },
  );

  test(
    'conflicting calculator identity cannot be credited or replace stored evidence',
    () async {
      final addon = testBolusWizard(
        createdAt: requestedAt.add(const Duration(minutes: 1)),
        carbs: 2,
        insulin: 17.8,
        nightscoutObjectId: 'accepted',
      );
      await db.localMirrorDao.upsertBolusWizard(
        addon.toCompanion(TreatmentsSource.aaps),
      );
      await db.localMirrorDao.upsertManualBolus(
        actual(addon).toCompanion(TreatmentsSource.aaps),
      );
      await expectLater(
        acceptMealAddOnBolus(
          db,
          1,
          addon.copyWith(nightscoutObjectId: 'rejected'),
          requestedAt: requestedAt,
        ),
        throwsA(isA<StateError>()),
      );
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 42);
      expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));
      expect(
        (await db.localMirrorDao.getBolusWizardsBetween(
          addon.createdAt,
          addon.createdAt,
        )).single.nightscoutId,
        'accepted',
      );
    },
  );
}
