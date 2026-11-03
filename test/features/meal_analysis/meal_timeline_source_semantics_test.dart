import 'package:clock/clock.dart';
import 'package:diabeatthis/common/history/history_event_type.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/bg_check.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_event_treatment.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/analyze_meal_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_device_status_history_repository.dart';
import '../../helpers/regression/scripted_glucose_history_repository.dart';
import '../../helpers/regression/scripted_read.dart';
import '../../helpers/regression/scripted_treatments_history_repository.dart';
import '../meals/data/repositories/nutrition_revision_test_fixture.dart';

void main() {
  test(
    'timeline preserves event identities and counts only delivered insulin in the observed window',
    () async {
      final details = nutritionRevisionMeal();
      final at = details.analysisTime;
      final eventAt = at.add(const Duration(minutes: 5));
      final cutoff = at.add(const Duration(minutes: 30));
      final chartStart = at.subtract(const Duration(minutes: 45));
      final sourceStart = at.subtract(const Duration(hours: 24));
      final spot = BgCheck(
        Glucose(
          externalId: 'spot',
          source: GlucoseSource.cloud,
          date: eventAt,
          sgv: 120,
          direction: '',
          type: GlucoseType.finger,
        ),
      );
      final stress = StressEventTreatment(
        StressEvent(
          occurredAt: eventAt,
          source: 'manual',
          stressLevel: StressLevel.high,
        ),
      );
      final manual = ManualBolus(
        externalId: 'manual',
        createdAt: eventAt,
        insulin: 2,
      );
      final correction = CorrectionBolus(
        externalId: 'smb',
        createdAt: eventAt,
        insulin: 1,
      );
      final wizard = BolusWizard(
        nightscoutObjectId: 'wizard',
        createdAt: eventAt,
        date: eventAt,
        glucose: 120,
        units: 'mg/dl',
        notes: null,
        calculatorResult: null,
      );
      final rescue = Treat(externalId: 'rescue', createdAt: eventAt, carbs: 10);
      final extended = ExtendedCarb(
        externalId: 'extended',
        createdAt: eventAt,
        carbs: 20,
        duration: 3600000,
      );
      final target = TemporaryTarget(
        nightscoutId: 'target',
        createdAt: eventAt,
        durationInMiliseconds: 1800000,
        duration: 30,
        targetBottom: 90,
        targetTop: 90,
      );
      final future = ManualBolus(
        externalId: 'future',
        createdAt: cutoff.add(const Duration(minutes: 1)),
        insulin: 99,
      );
      final invalid = ManualBolus(
        externalId: 'invalid',
        createdAt: eventAt,
        insulin: 99,
        isValid: false,
      );
      final glucose = ScriptedRead<List<Glucose>>('CGM', [
        (arguments: [chartStart, cutoff], respond: () => []),
      ]);
      final treatments = ScriptedRead<List<Treatment>>('treatments', [
        (
          arguments: [sourceStart, cutoff],
          respond: () => [
            spot,
            stress,
            manual,
            correction,
            wizard,
            rescue,
            extended,
            target,
            future,
            invalid,
          ],
        ),
      ]);
      final devices = ScriptedRead<List<DeviceStatus>>('devices', [
        (arguments: [chartStart, cutoff], respond: () => []),
      ]);
      final before = ScriptedRead<DeviceStatus?>(
        'unexpected device lookup',
        [],
      );
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) async => ScriptedGlucoseHistoryRepository(glucose),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) async => ScriptedTreatmentsHistoryRepository(treatments),
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) async =>
                ScriptedDeviceStatusHistoryRepository(devices, before),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final result = (await withClock(
        Clock.fixed(cutoff),
        () => container.read(analyzeMealUseCaseProvider)(details, asOf: cutoff),
      ))!;
      final events = result.timelineEvents
          .where((event) => event.timestamp == eventAt)
          .toList();
      expect(
        events.map((event) => event.type),
        unorderedEquals([
          HistoryEventType.bgCheck,
          HistoryEventType.stress,
          HistoryEventType.manualCorrection,
          HistoryEventType.correction,
          HistoryEventType.bolusWizard,
          HistoryEventType.carbs,
          HistoryEventType.carbs,
          HistoryEventType.tempTarget,
        ]),
      );
      expect(result.temporaryTargets, [target]);
      expect(result.chartEnd, cutoff);
      expect(result.glucoseReadings, isEmpty);
      expect(result.outcomeContext!.boluses.units, 3);
      expect(result.outcomeContext!.boluses.manualUnits, 2);
      expect(result.outcomeContext!.boluses.otherUnits, 1);
      expect(result.outcomeContext!.glucose, isEmpty);
      expect(result.outcomeContext!.glucoseSummary.mean, isNull);
      expect(
        result.timelineEvents.any((event) => event.timestamp.isAfter(cutoff)),
        false,
      );
      glucose.verifyComplete();
      treatments.verifyComplete();
      devices.verifyComplete();
      before.verifyComplete();
    },
  );

  for (final scenario in ['not-eaten', 'before-meal']) {
    test('$scenario cannot access history or fabricate an analysis', () async {
      final details = nutritionRevisionMeal(
        status: scenario == 'not-eaten' ? 'planned' : 'eaten',
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected database read'),
          ),
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) => throw StateError('Unexpected glucose source'),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) => throw StateError('Unexpected treatment source'),
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) => throw StateError('Unexpected device source'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final operation = withClock(
        Clock.fixed(details.analysisTime.add(const Duration(hours: 1))),
        () => container.read(analyzeMealUseCaseProvider)(
          details,
          asOf: details.analysisTime.subtract(const Duration(minutes: 1)),
        ),
      );
      if (scenario == 'not-eaten') {
        expect(await operation, isNull);
      } else {
        await expectLater(operation, throwsArgumentError);
      }
    });
  }
}
