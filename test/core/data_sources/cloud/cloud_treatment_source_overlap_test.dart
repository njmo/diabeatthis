import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/cloud/cloud_treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository.dart';
import 'package:diabeatthis/core/domain/model/bg_check.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:flutter_test/flutter_test.dart';

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
