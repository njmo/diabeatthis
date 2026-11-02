import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/calculator_submission_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_runtime_harness.dart';

void main() {
  test('raw broadcasts expose pending wizard before delivery settles', () {
    fakeAsync((async) {
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
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      final handler = ExternalEventHandler(harness.runtimeContext);
      handler.handle(
        broadcast({
          'eventType': 'Meal Bolus',
          'created_at': '2026-11-02T14:05:49.000Z',
          'carbs': 48,
        }),
      );
      async.elapse(const Duration(milliseconds: 800));
      handler.handle(
        broadcast({
          'eventType': 'Bolus Wizard',
          'created_at': '2026-11-02T14:05:49.800Z',
          'glucose': 120,
          'bolusCalculatorResult': {'carbs': 48, 'totalInsulin': 3},
        }),
      );
      async.elapse(const Duration(seconds: 7));
      expect(
        harness.emittedEvents
            .whereType<CalculatorSubmissionChangedEvent>()
            .single
            .submission
            .status,
        CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<ManualBolus>>(),
        isEmpty,
      );
      handler.handle(
        broadcast({
          'eventType': 'Meal Bolus',
          'created_at': '2026-11-02T14:05:49.900Z',
          'insulin': 3,
        }),
      );
      async.elapse(const Duration(seconds: 1));
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<BolusWizard>>(),
        hasLength(2),
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<ManualBolus>>(),
        hasLength(1),
      );
      final submissions = harness.emittedEvents
          .whereType<CalculatorSubmissionChangedEvent>()
          .map((event) => event.submission)
          .toList();
      expect(submissions.map((submission) => submission.status), [
        CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
        CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
        CalculatorSubmissionStatus.deliveryConfirmed,
      ]);
      expect(submissions.first.wizard.carbohydrateRecord, isNull);
      expect(submissions[1].wizard.carbohydrateRecord?.carbs, 48);
      expect(
        submissions[1].wizard.carbohydrateRecord?.createdAt.isAtSameMomentAs(
          DateTime.parse('2026-11-02T14:05:49.000Z'),
        ),
        isTrue,
      );
      expect(submissions[1].delivery, isNull);
      expect(submissions[1].isComplete, isFalse);
      expect(submissions.last.deliveredInsulin, 3);
      expect(async.pendingTimers, isEmpty);
      harness.dispose();
      async.flushMicrotasks();
    });
  });

  test('orderly shutdown flushes an incomplete calculator before teardown', () {
    fakeAsync((async) {
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
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      final handler = ExternalEventHandler(harness.runtimeContext);
      handler.handle(
        broadcast({
          'eventType': 'Bolus Wizard',
          'created_at': '2026-11-02T14:05:49.800Z',
          'glucose': 120,
          'bolusCalculatorResult': {'carbs': 48, 'totalInsulin': 3},
        }),
      );
      var flushed = false;
      handler.flushPendingTreatments().then((_) => flushed = true);
      async.flushMicrotasks();
      expect(flushed, isTrue);
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<BolusWizard>>(),
        hasLength(1),
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<ManualBolus>>(),
        isEmpty,
      );
      expect(async.pendingTimers, isEmpty);
      harness.dispose();
      async.flushMicrotasks();
    });
  });
}

Map<String, dynamic> broadcast(Map<String, dynamic> record) => {
  'external_event': 'native_receiver',
  'data': {
    'kind': 'treatments',
    'data': {'data': record},
  },
};
