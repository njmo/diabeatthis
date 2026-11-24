import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/task/task_data_synchronization_payload.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/models/wizard_carbohydrate_component.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/manual_bolus.dart' as domain;
import 'package:diabeatthis/core/domain/model/temporary_target.dart' as domain;
import 'package:diabeatthis/core/domain/model/treat.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_event.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_handler.dart';
import 'package:diabeatthis/foreground/event/internal/calculator_submission_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
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

    for (final replay in [
      (
        name: '08:49 interrupted',
        wizardAt: '07:49:13.648',
        insulinAt: '07:49:15.338',
        carbsAt: '07:49:12.990',
        carbs: 17,
        initial: 1.75,
        expected: 1.2,
        batches: [
          ('07:49:15.297', ['wizard', 'wizard']),
          ('07:49:23.696', ['wizard', 'wizard', 'insulin']),
          ('07:49:26.757', ['insulin', 'insulin']),
          ('07:49:36.886', ['insulin']),
          ('07:50:06.453', ['correction', 'carbs']),
          ('07:50:17.230', ['correction', 'carbs', 'carbs']),
          ('07:50:27.422', ['carbs']),
        ],
      ),
      (
        name: '16:12 unchanged',
        wizardAt: '15:12:06.459',
        insulinAt: '15:12:09.307',
        carbsAt: '15:12:05.668',
        carbs: 16,
        initial: 1.15,
        expected: 1.15,
        batches: [
          ('15:12:07.945', ['wizard', 'wizard']),
          ('15:12:16.526', ['wizard', 'wizard', 'insulin']),
          ('15:12:20.743', ['insulin', 'insulin']),
          ('15:12:30.814', ['insulin']),
          ('15:13:00.348', ['carbs']),
          ('15:13:13.986', ['carbs']),
          ('15:13:19.382', ['carbs']),
        ],
      ),
      (
        name: '19:52 scheduled eCarbs repeated before and after the wizard',
        wizardAt: '18:53:09.653',
        insulinAt: '18:53:12.066',
        carbsAt: '18:53:08.533',
        carbs: 31,
        initial: 1.85,
        expected: 1.85,
        batches: [
          ('18:52:58.431', ['extended']),
          ('18:53:08.746', ['extended', 'extended']),
          ('18:53:11.135', ['wizard', 'wizard']),
          ('18:53:13.199', ['insulin']),
          ('18:53:23.529', ['extendedWithId']),
          ('18:54:31.279', ['carbs']),
        ],
      ),
    ]) {
      test('replays AAPS mirror batches from ${replay.name}', () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dataSourceConfigProvider.overrideWithValue(
              const AsyncData(
                DataSourceConfig(
                  bgSource: BgSource.aaps,
                  treatmentsSource: TreatmentsSource.aaps,
                  pumpStatusSource: PumpStatusSource.aaps,
                  historySource: HistorySource.local,
                  mirrorToLocal: true,
                ),
              ),
            ),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        addTearDown(() async {
          await harness.dispose();
          await db.close();
        });
        final handler = LocalTreatmentsHandler();
        DateTime at(String time) => DateTime.parse('2026-11-24T${time}Z');
        final wizard = {
          'eventType': 'Bolus Wizard',
          'created_at': at(replay.wizardAt).toIso8601String(),
          'glucose': 120,
          'bolusCalculatorResult': {
            'carbs': replay.carbs,
            'totalInsulin': replay.initial,
          },
        };
        final insulin = {
          'eventType': 'Meal Bolus',
          'created_at': at(replay.insulinAt).toIso8601String(),
          'insulin': replay.initial,
        };
        final carbs = {
          'eventType': 'Meal Bolus',
          'created_at': at(replay.carbsAt).toIso8601String(),
          'carbs': replay.carbs,
        };
        final extended = {
          'eventType': 'Meal Bolus',
          'created_at': at('19:37:50.000').toIso8601String(),
          'carbs': 21,
          'duration': const Duration(hours: 2).inMilliseconds,
        };
        final payloads = {
          'extended': extended,
          'extendedWithId': {...extended, '_id': 'test-ns-ecarbs'},
          'wizard': wizard,
          'insulin': insulin,
          'correction': {...insulin, 'insulin': replay.expected},
          'carbs': carbs,
        };
        var hasWizard = false;
        var hasExtended = false;
        for (final (receivedAt, records) in replay.batches) {
          hasWizard |= records.contains('wizard');
          hasExtended |= records.contains('extended');
          await withClock(
            Clock.fixed(at(receivedAt)),
            () => handler.handle(
              LocalTreatmentsEvent.fromJson({
                'data': [for (final name in records) payloads[name]!],
              }),
              harness.runtimeContext,
            ),
          );
          expect(
            await db.select(db.bolusWizard).get(),
            hasLength(hasWizard ? 1 : 0),
          );
          final extendedRows = await db.select(db.extendedCarb).get();
          expect(extendedRows, hasLength(hasExtended ? 1 : 0));
          if (hasExtended) expect(extendedRows.single.carbs, 21);
          expect(
            await db.select(db.manualBolus).get(),
            hasLength(lessThanOrEqualTo(1)),
          );
          expect(await db.select(db.treat).get(), isEmpty);
        }

        final cached = container.read(calculatorSubmissionsProvider).single;
        expect(cached.deliveredInsulin, replay.expected);
        expect(cached.wizard.carbohydrateRecord?.carbs, replay.carbs);
        expect(
          (await db.select(db.manualBolus).get()).single.insulin,
          replay.expected,
        );
        final start = at(replay.carbsAt).subtract(const Duration(seconds: 1));
        final end = start.add(const Duration(minutes: 5));
        final history = await LocalTreatmentsHistoryRepository(
          db.localMirrorDao,
        ).fetchTreatmentsBetween(start, end);
        final summary = InsulinBolusSummary.fromTreatments(
          treatments: history,
          start: start,
          end: end,
        );
        expect(summary.wizardCount, 1);
        expect(summary.wizardUnits, replay.expected);
        expect(summary.manualCount, 0);
        expect(
          harness.emittedEvents
              .whereType<TreatmentAvailableEvent<domain.BolusWizard>>(),
          hasLength(1),
        );
        expect(
          harness.emittedEvents
              .whereType<TreatmentAvailableEvent<domain.ManualBolus>>(),
          isEmpty,
        );
        expect(
          harness.emittedEvents
              .whereType<TreatmentAvailableEvent<domain.Treat>>(),
          isEmpty,
        );
      });
    }

    for (final order in ['same batch', 'wizard first', 'insulin first']) {
      test(
        'retains matched insulin and revisions in the mirror ($order)',
        () async {
          final db = DatabaseImpl(NativeDatabase.memory());
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              dataSourceConfigProvider.overrideWithValue(
                const AsyncData(
                  DataSourceConfig(
                    bgSource: BgSource.aaps,
                    treatmentsSource: TreatmentsSource.aaps,
                    pumpStatusSource: PumpStatusSource.aaps,
                    historySource: HistorySource.local,
                    mirrorToLocal: true,
                  ),
                ),
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          addTearDown(() async {
            await harness.dispose();
            await db.close();
          });
          final handler = LocalTreatmentsHandler();
          Future<void> receive(List<Map<String, dynamic>> records) =>
              handler.handle(
                LocalTreatmentsEvent.fromJson({'data': records}),
                harness.runtimeContext,
              );
          final insulinAt = _bolusWizardCreatedAt.add(
            const Duration(seconds: 6),
          );
          final insulin = {
            ..._manualBolusPayload(isValid: true, insulin: 2.95),
            'created_at': insulinAt.toIso8601String(),
          }..remove('_id');
          final wizard = _bolusWizardPayload();
          if (order == 'same batch') {
            await receive([insulin, _treatPayload(), wizard]);
          } else if (order == 'wizard first') {
            await receive([wizard]);
            await receive([insulin, _treatPayload()]);
          } else {
            await receive([insulin]);
            await receive([wizard, _treatPayload()]);
          }
          final firstBolus = (await db.select(db.manualBolus).get()).single;
          expect(firstBolus.insulin, 2.95);
          expect(firstBolus.externalId, isNull);
          expect(await db.select(db.treat).get(), isEmpty);
          expect(await db.select(db.bolusWizard).get(), hasLength(1));
          expect(
            harness.emittedEvents
                .whereType<TreatmentAvailableEvent<domain.BolusWizard>>(),
            hasLength(1),
          );

          await receive([
            {...insulin, '_id': 'manual-1'},
            {...insulin, '_id': 'manual-1', 'insulin': 1.5},
          ]);
          final corrected = (await db.select(db.manualBolus).get()).single;
          expect(corrected.insulin, 1.5);
          expect(corrected.externalId, 'manual-1');

          await receive([
            {
              ...insulin,
              '_id': 'standalone',
              'created_at': insulinAt
                  .add(const Duration(minutes: 3))
                  .toIso8601String(),
            },
          ]);
          expect(
            (await db.select(db.manualBolus).get()).map(
              (row) => row.externalId,
            ),
            containsAll(['manual-1', 'standalone']),
          );
        },
      );
    }

    test(
      'attaches calculator carbohydrates while preserving actual delivery from separate broadcasts',
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
        expect(treats, isEmpty);
        expect(
          WizardCarbohydrateComponent.fromJson(
            bolusWizards.single.carbohydrateComponent!,
          ).externalId,
          'treat-1',
        );
        expect(
          harness.emittedEvents
              .whereType<TreatmentAvailableEvent<domain.BolusWizard>>(),
          hasLength(1),
        );
        expect(
          harness.emittedEvents
              .whereType<TreatmentAvailableEvent<domain.Treat>>(),
          isEmpty,
        );
        // This fixture's insulin timestamp is three milliseconds before the
        // wizard. Preserve it as an independent bolus rather than assigning it.
        expect(
          harness.emittedEvents
              .whereType<TreatmentAvailableEvent<domain.ManualBolus>>(),
          hasLength(1),
        );
        final updates = harness.emittedEvents
            .whereType<CalculatorSubmissionChangedEvent>();
        expect(updates, hasLength(2));
        expect(
          updates.last.submission.wizard.carbohydrateRecord?.externalId,
          'treat-1',
        );
        expect(updates.last.submission.delivery, isNull);

        await harness.dispose();
        await db.close();
      },
    );

    test(
      'attaches carbohydrates received before their matching calculator record',
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
        expect(treats, isEmpty);
        expect(
          WizardCarbohydrateComponent.fromJson(
            bolusWizards.single.carbohydrateComponent!,
          ).externalId,
          'treat-1',
        );

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
