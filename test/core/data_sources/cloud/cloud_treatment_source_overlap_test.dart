import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/cloud/cloud_treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/repositories/mirroring_treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository.dart';
import 'package:diabeatthis/core/domain/model/bg_check.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/wait_for_meal_bolus_delivery.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_runtime_harness.dart';

void main() {
  final start = DateTime(2026, 11, 2, 12);
  late DateTime now;
  late PollingNightscoutRepository remote;
  late CloudTreatmentSourceRepository source;

  setUp(() {
    now = start;
    remote = PollingNightscoutRepository();
    source = withClock(
      Clock(() => now),
      () => CloudTreatmentSourceRepository(remote),
    );
  });

  Future<List<Treatment>> poll() =>
      withClock(Clock(() => now), source.pollTreatments);

  test(
    'calculator advances from the first snapshot and the next adds its insulin',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(() async {
        await harness.dispose();
        await db.close();
      });
      final repository = MirroringTreatmentSourceRepository(
        delegate: source,
        mirrorWriter: LocalMirrorWriter(db.localMirrorDao),
        source: TreatmentsSource.cloud,
      );
      final dispatcher = TreatmentEventDispatcher();
      Future<List<Treatment>> pollAndDispatch() async {
        final result = await withClock(
          Clock(() => now),
          repository.pollTreatments,
        );
        dispatcher.dispatchBatch(
          container: container,
          emitEvent: harness.runtimeContext.emitEvent,
          treatments: result.reversed,
        );
        return result;
      }

      final carbAt = start.add(const Duration(seconds: 10));
      final wizardAt = carbAt.add(const Duration(seconds: 1));
      final insulinAt = wizardAt.add(const Duration(seconds: 2));
      final carbs = {
        '_id': 'carbs',
        'eventType': 'Meal Bolus',
        'created_at': carbAt.toIso8601String(),
        'carbs': 17,
      };
      final wizard = {
        '_id': 'wizard',
        'eventType': 'Bolus Wizard',
        'created_at': wizardAt.toIso8601String(),
        'glucose': 120,
        'bolusCalculatorResult': {'carbs': 17, 'totalInsulin': 1.75},
      };
      final insulin = {
        '_id': 'insulin',
        'eventType': 'Meal Bolus',
        'created_at': insulinAt.toIso8601String(),
        'insulin': 1.2,
      };
      List<Treatment> readSnapshot(List<Map<String, Object>> records) =>
          TreatmentFactory().parseTreatments(
            records,
            remoteSource: 'nightscout',
          );

      remote.treatments = readSnapshot([wizard, carbs]);
      now = start.add(const Duration(minutes: 1));
      expect(await pollAndDispatch(), hasLength(2));
      final entry = harness.emittedEvents
          .whereType<TreatmentAvailableEvent<BolusWizard>>()
          .single
          .data;
      expect(entry.carbohydrateRecord?.carbs, 17);
      final accepted = await const WaitForMealBolusDelivery()(
        harness.runtimeContext,
        MealMonitorContext(
          activeMeal: Meal(id: 91, name: 'Meal', status: 'waiting-for-bolus'),
        ),
        entry,
        requireRecordedBolus: false,
      );
      expect(accepted.recommendedInsulin, 1.75);
      expect(accepted.deliveredInsulin, isNull);

      remote.treatments = readSnapshot([insulin, wizard, carbs]);
      now = start.add(const Duration(minutes: 2));
      expect(await pollAndDispatch(), [isA<ManualBolus>()]);
      final submission = container.read(calculatorSubmissionsProvider).single;
      expect(submission.key.isAtSameMomentAs(wizardAt), isTrue);
      expect(submission.deliveredInsulin, 1.2);
      expect(await db.select(db.bolusWizard).get(), hasLength(1));
      expect(await db.select(db.treat).get(), isEmpty);
      expect((await db.select(db.manualBolus).get()).single.insulin, 1.2);
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<BolusWizard>>(),
        hasLength(1),
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<ManualBolus>>(),
        isEmpty,
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<Treat>>(),
        isEmpty,
      );
    },
  );

  test(
    'finds late-uploaded delivery and carbs less than one second after a calculator',
    () async {
      final wizard = cloudWizard(start.add(const Duration(seconds: 1)));
      final delivery = ManualBolus(
        externalId: 'delivery',
        createdAt: wizard.createdAt.add(const Duration(milliseconds: 830)),
        insulin: 3,
      );
      final carbs = Treat(
        externalId: 'carbs',
        createdAt: wizard.createdAt.add(const Duration(milliseconds: 831)),
        carbs: 48,
      );
      remote.treatments = [wizard];
      now = start.add(const Duration(seconds: 2));
      expect(await poll(), [wizard]);

      now = start.add(const Duration(minutes: 3));
      remote.treatments = [carbs, wizard.copyWith(), delivery];
      expect(await poll(), [delivery, carbs]);
      expect(remote.requestedAfter.last, start);
      expect(await poll(), isEmpty);
    },
  );

  test(
    'keeps different component types at the same timestamp and suppresses unchanged snapshots',
    () async {
      final wizard = cloudWizard(start);
      final delivery = ManualBolus(
        externalId: 'delivery',
        createdAt: start,
        insulin: 3,
      );
      final carbs = Treat(externalId: 'carbs', createdAt: start, carbs: 48);
      remote.treatments = [wizard, delivery, carbs];
      expect(await poll(), unorderedEquals([wizard, delivery, carbs]));
      remote.treatments = [
        carbs.copyWith(),
        delivery.copyWith(),
        wizard.copyWith(),
      ];
      expect(await poll(), isEmpty);
    },
  );

  test(
    'emits corrections and invalidations once without losing a later restoration',
    () async {
      final wizard = cloudWizard(start);
      final delivery = ManualBolus(
        externalId: 'delivery',
        createdAt: start,
        insulin: 3,
      );
      remote.treatments = [wizard, delivery];
      await poll();
      final corrected = delivery.copyWith(insulin: 2);
      final correctedWizard = wizard.copyWith(notes: 'Updated calculator');
      remote.treatments = [corrected, correctedWizard];
      expect(await poll(), unorderedEquals([corrected, correctedWizard]));
      expect(await poll(), isEmpty);
      final invalid = corrected.copyWith(isValid: false);
      remote.treatments = [correctedWizard, invalid];
      expect(await poll(), [invalid]);
      expect(await poll(), isEmpty);
      remote.treatments = [correctedWizard, corrected];
      expect(await poll(), [corrected]);
    },
  );

  test(
    'preserves the initial live boundary instead of replaying older history',
    () async {
      final old = cloudWizard(start.subtract(const Duration(seconds: 1)));
      final current = cloudWizard(start);
      remote.treatments = [old, current];
      expect(await poll(), [current]);
      expect(remote.requestedAfter.single, start);
    },
  );

  test('advances a bounded overlap on successful empty polls', () async {
    await poll();
    now = start.add(const Duration(minutes: 7));
    await poll();
    now = start.add(const Duration(minutes: 8));
    await poll();
    expect(remote.requestedAfter, [
      start,
      start,
      start.add(const Duration(minutes: 2)),
    ]);
  });

  test('a failed request does not advance past late components', () async {
    final wizard = cloudWizard(start.add(const Duration(seconds: 1)));
    remote.treatments = [wizard];
    expect(await poll(), [wizard]);
    now = start.add(const Duration(minutes: 7));
    remote.failNextRequest = true;
    await expectLater(poll(), throwsStateError);
    final delivery = ManualBolus(
      externalId: 'late-delivery',
      createdAt: wizard.createdAt.add(const Duration(milliseconds: 800)),
      insulin: 3,
    );
    remote.treatments = [wizard, delivery];
    now = start.add(const Duration(minutes: 8));
    expect(await poll(), [delivery]);
    expect(remote.requestedAfter.last, start);
  });

  test(
    'a future-dated source record cannot move the poll cursor forward',
    () async {
      final future = cloudWizard(start.add(const Duration(hours: 1)));
      remote.treatments = [future];
      expect(await poll(), [future]);
      final current = cloudWizard(start.add(const Duration(seconds: 1)));
      remote.treatments = [future, current];
      now = start.add(const Duration(seconds: 2));
      expect(await poll(), [current]);
      expect(remote.requestedAfter.last, start);
    },
  );

  test(
    'deduplicates equivalent glucose check objects while keeping edits',
    () async {
      final reading = Glucose(
        externalId: 'check',
        source: GlucoseSource.cloud,
        date: start,
        sgv: 120,
        direction: 'Flat',
      );
      remote.treatments = [BgCheck(reading)];
      expect(await poll(), hasLength(1));
      remote.treatments = [BgCheck(reading.copyWith())];
      expect(await poll(), isEmpty);
      remote.treatments = [BgCheck(reading.copyWith(sgv: 125))];
      expect(await poll(), hasLength(1));
    },
  );

  test(
    'preserves target expiry notifications without duplicate history rows',
    () async {
      final target = TemporaryTarget(
        nightscoutId: 'target',
        createdAt: start,
        durationInMiliseconds: 60000,
        duration: 1,
        targetBottom: 90,
        targetTop: 110,
      );
      remote.activeTarget = target;
      remote.treatments = [target];
      expect(await poll(), [target]);
      expect(await poll(), isEmpty);
      now = start.add(const Duration(minutes: 2));
      expect(await poll(), [target]);
      expect(await poll(), isEmpty);
    },
  );
}

BolusWizard cloudWizard(DateTime time) =>
    TreatmentFactory().parseTreatments([
          {
            '_id': 'wizard-${time.millisecondsSinceEpoch}',
            'eventType': 'Bolus Wizard',
            'created_at': time.toIso8601String(),
            'glucose': 120,
            'bolusCalculatorResult': {'carbs': 48, 'totalInsulin': 44.7},
          },
        ]).single
        as BolusWizard;

class PollingNightscoutRepository implements NightscoutRepository {
  List<Treatment> treatments = [];
  final List<DateTime> requestedAfter = [];
  TemporaryTarget? activeTarget;
  bool failNextRequest = false;

  @override
  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after) async {
    requestedAfter.add(after);
    if (failNextRequest) {
      failNextRequest = false;
      throw StateError('Unavailable history');
    }
    return treatments
        .where((record) => !record.createdAt!.isBefore(after))
        .toList();
  }

  @override
  Future<TemporaryTarget> fetchLastTemporaryTarget() async =>
      activeTarget ?? (throw StateError('No temporary target'));

  @override
  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id) async =>
      activeTarget ?? (throw StateError('No temporary target'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
