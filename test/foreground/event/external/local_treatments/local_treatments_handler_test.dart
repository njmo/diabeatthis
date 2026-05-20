import 'package:diabeatthis/common/events/data/task/task_data_synchronization_payload.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/manual_bolus.dart' as domain;
import 'package:diabeatthis/core/domain/model/temporary_target.dart' as domain;
import 'package:diabeatthis/core/domain/model/treat.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_event.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_handler.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_runtime_harness.dart';

void main() {
  group('LocalTreatmentsHandler', () {
    test(
      'emits treatment event and syncs temporary target for AAPS source',
      () async {
        final target = domain.TemporaryTarget(
          nightscoutId: 'target-1',
          createdAt: DateTime(2026, 5, 18, 21, 12),
          durationInMiliseconds: 1800000,
          duration: 30,
          targetBottom: 90,
          targetTop: 110,
        );
        final router = RecordingTaskEventRouter();
        final container = ProviderContainer(
          overrides: [
            dataSourceConfigProvider.overrideWithValue(
              const AsyncData(
                DataSourceConfig(
                  bgSource: BgSource.cloud,
                  treatmentsSource: TreatmentsSource.aaps,
                  pumpStatusSource: PumpStatusSource.cloud,
                  historySource: HistorySource.cloud,
                  mirrorToLocal: false,
                ),
              ),
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);

        await LocalTreatmentsHandler().handle(
          LocalTreatmentsEvent(data: [target], rawPayloads: const []),
          harness.runtimeContext,
        );

        expect(harness.emittedEvents, [
          isA<TreatmentAvailableEvent<domain.TemporaryTarget>>(),
        ]);
        expect(
          container
              .read(synchronizationCacheControllerProvider)
              .getCache()
              .targetCache,
          target,
        );
        expect(harness.emittedTicks, isEmpty);
        expect(router.payloads, [TaskTargetSynchronization(data: target)]);

        await harness.dispose();
      },
    );

    test('ignores treatments when configured source is not AAPS', () async {
      final target = domain.TemporaryTarget(
        nightscoutId: 'target-1',
        createdAt: DateTime(2026, 5, 18, 21, 12),
        durationInMiliseconds: 1800000,
        duration: 30,
        targetBottom: 90,
        targetTop: 110,
      );
      final container = ProviderContainer(
        overrides: [
          dataSourceConfigProvider.overrideWithValue(
            const AsyncData(DataSourceConfig.defaults()),
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);

      await LocalTreatmentsHandler().handle(
        LocalTreatmentsEvent(data: [target], rawPayloads: const []),
        harness.runtimeContext,
      );

      expect(harness.emittedEvents, isEmpty);
      expect(
        container
            .read(synchronizationCacheControllerProvider)
            .getCache()
            .targetCache,
        isNull,
      );

      await harness.dispose();
    });

    test(
      'updates mirrored AAPS treatment from repeated local broadcast',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final router = RecordingTaskEventRouter();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dataSourceConfigProvider.overrideWithValue(
              const AsyncData(
                DataSourceConfig(
                  bgSource: BgSource.cloud,
                  treatmentsSource: TreatmentsSource.aaps,
                  pumpStatusSource: PumpStatusSource.cloud,
                  historySource: HistorySource.cloud,
                  mirrorToLocal: true,
                ),
              ),
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);

        await db.localMirrorDao.upsertTemporaryTarget(
          TemporaryTargetCompanion.insert(
            source: TreatmentsSource.aaps.storageValue,
            externalId: const Value('target-1'),
            createdAt: Value(_targetCreatedAt.millisecondsSinceEpoch),
            durationMinutes: const Value(30),
            targetBottom: const Value(90),
            targetTop: const Value(120),
          ),
        );

        await LocalTreatmentsHandler().handle(
          LocalTreatmentsEvent.fromJson({
            'data': [_temporaryTargetPayload(duration: 5, targetTop: 100)],
          }),
          harness.runtimeContext,
        );

        final targets = await db.localMirrorDao.getTemporaryTargetsBetween(
          DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(2000000000000),
          source: TreatmentsSource.aaps.storageValue,
        );

        expect(targets, hasLength(1));
        expect(targets.single.externalId, 'target-1');
        expect(targets.single.durationMinutes, 5);
        expect(targets.single.targetTop, 100);
        expect(harness.emittedEvents, [
          isA<TreatmentAvailableEvent<domain.TemporaryTarget>>(),
        ]);

        await harness.dispose();
        await db.close();
      },
    );

    test(
      'preserves bolus wizard related treatments from separate broadcasts',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
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
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        final handler = LocalTreatmentsHandler();

        await handler.handle(
          LocalTreatmentsEvent.fromJson({
            'data': [_bolusWizardPayload()],
          }),
          harness.runtimeContext,
        );

        await handler.handle(
          LocalTreatmentsEvent.fromJson({
            'data': [
              _manualBolusPayload(isValid: true, insulin: 2.95),
              _treatPayload(),
            ],
          }),
          harness.runtimeContext,
        );

        final start = DateTime.fromMillisecondsSinceEpoch(0);
        final end = DateTime.fromMillisecondsSinceEpoch(2000000000000);
        final bolusWizards = await db.localMirrorDao.getBolusWizardsBetween(
          start,
          end,
          source: TreatmentsSource.aaps.storageValue,
        );
        final manualBoluses = await db.localMirrorDao.getManualBolusesBetween(
          start,
          end,
          source: TreatmentsSource.aaps.storageValue,
        );
        final treats = await db.localMirrorDao.getTreatsBetween(
          start,
          end,
          source: TreatmentsSource.aaps.storageValue,
        );

        expect(bolusWizards, hasLength(1));
        expect(manualBoluses, hasLength(1));
        expect(treats, hasLength(1));
        expect(harness.emittedEvents, [
          isA<TreatmentAvailableEvent<domain.BolusWizard>>(),
          isA<TreatmentAvailableEvent<domain.ManualBolus>>(),
          isA<TreatmentAvailableEvent<domain.Treat>>(),
        ]);

        await harness.dispose();
        await db.close();
      },
    );

    test(
      'preserves treatment received before matching bolus wizard record',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
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
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        final handler = LocalTreatmentsHandler();

        await handler.handle(
          LocalTreatmentsEvent.fromJson({
            'data': [_treatPayload()],
          }),
          harness.runtimeContext,
        );

        await handler.handle(
          LocalTreatmentsEvent.fromJson({
            'data': [
              _bolusWizardPayload(),
              _manualBolusPayload(isValid: true, insulin: 2.95),
            ],
          }),
          harness.runtimeContext,
        );

        final start = DateTime.fromMillisecondsSinceEpoch(0);
        final end = DateTime.fromMillisecondsSinceEpoch(2000000000000);
        final bolusWizards = await db.localMirrorDao.getBolusWizardsBetween(
          start,
          end,
          source: TreatmentsSource.aaps.storageValue,
        );
        final manualBoluses = await db.localMirrorDao.getManualBolusesBetween(
          start,
          end,
          source: TreatmentsSource.aaps.storageValue,
        );
        final treats = await db.localMirrorDao.getTreatsBetween(
          start,
          end,
          source: TreatmentsSource.aaps.storageValue,
        );

        expect(bolusWizards, hasLength(1));
        expect(manualBoluses, hasLength(1));
        expect(treats, hasLength(1));
        expect(treats.single.externalId, 'treat-1');

        await harness.dispose();
        await db.close();
      },
    );

    test('removes invalidated AAPS treatment from local mirror', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
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
        ],
      );
      final harness = FakeRuntimeHarness(container: container);

      await db.localMirrorDao.upsertManualBolus(
        ManualBolusCompanion.insert(
          source: TreatmentsSource.aaps.storageValue,
          externalId: const Value('manual-1'),
          createdAt: Value(_manualBolusCreatedAt.millisecondsSinceEpoch),
          insulin: const Value(1.2),
        ),
      );

      await LocalTreatmentsHandler().handle(
        LocalTreatmentsEvent.fromJson({
          'data': [_manualBolusPayload(isValid: false)],
        }),
        harness.runtimeContext,
      );

      final manualBoluses = await db.localMirrorDao.getManualBolusesBetween(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(2000000000000),
        source: TreatmentsSource.aaps.storageValue,
      );

      expect(manualBoluses, isEmpty);
      expect(harness.emittedEvents, isEmpty);

      await harness.dispose();
      await db.close();
    });
  });
}

class RecordingTaskEventRouter extends TaskEventRouter {
  final List<TaskEventPayload> payloads = [];

  @override
  void send(TaskEventPayload payload) {
    payloads.add(payload);
  }
}

final _targetCreatedAt = DateTime.utc(2026, 5, 18, 21, 12);
final _bolusWizardCreatedAt = DateTime.utc(2026, 5, 18, 21, 20, 23, 210);
final _manualBolusCreatedAt = DateTime.utc(2026, 5, 18, 21, 20, 23, 207);
final _treatCreatedAt = DateTime.utc(2026, 5, 18, 21, 20, 21, 919);

Map<String, dynamic> _temporaryTargetPayload({
  int duration = 30,
  int targetTop = 110,
}) {
  return {
    '_id': 'target-1',
    'eventType': 'Temporary Target',
    'created_at': _targetCreatedAt.toIso8601String(),
    'durationInMilliseconds': Duration(minutes: duration).inMilliseconds,
    'duration': duration,
    'targetBottom': 90,
    'targetTop': targetTop,
  };
}

Map<String, dynamic> _manualBolusPayload({
  required bool isValid,
  double insulin = 1.2,
}) {
  return {
    '_id': 'manual-1',
    'eventType': 'Meal Bolus',
    'created_at': _manualBolusCreatedAt.toIso8601String(),
    'insulin': insulin,
    'isValid': isValid,
  };
}

Map<String, dynamic> _bolusWizardPayload() {
  return {
    '_id': 'wizard-1',
    'eventType': 'Bolus Wizard',
    'created_at': _bolusWizardCreatedAt.toIso8601String(),
    'date': _bolusWizardCreatedAt.millisecondsSinceEpoch,
    'glucose': 98,
    'units': 'mg/dl',
    'bolusCalculatorResult': {'carbs': 42, 'totalInsulin': 2.95},
    'isValid': true,
  };
}

Map<String, dynamic> _treatPayload() {
  return {
    '_id': 'treat-1',
    'eventType': 'Carb Correction',
    'created_at': _treatCreatedAt.toIso8601String(),
    'carbs': 42,
    'isValid': true,
  };
}
