import 'dart:convert';

import 'package:diabeatthis/common/meal/calculator/calculator_request_command.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller_provider.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/calculator_submission_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
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
        hasLength(1),
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<ManualBolus>>(),
        isEmpty,
      );
      final submissions = harness.emittedEvents
          .whereType<CalculatorSubmissionChangedEvent>()
          .map((event) => event.submission)
          .toList();
      expect(submissions.map((submission) => submission.status), [
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
      expect(submissions.last.deliveredInsulin, 3);
      expect(async.pendingTimers, isEmpty);
      harness.dispose();
      async.flushMicrotasks();
    });
  });

  const dashScenarios = [
    (name: 'normal delivery', stopped: false, bolusFirst: false),
    (name: 'stopped delivery', stopped: true, bolusFirst: false),
    (
      name: 'insulin arrives before the wizard',
      stopped: false,
      bolusFirst: true,
    ),
  ];
  for (final scenario in dashScenarios) {
    test('AAPS 3ca34428 DASH one-minute delivery: ${scenario.name}', () {
      fakeAsync((async) {
        final opened = DateTime.utc(2026, 11, 23, 18, 47, 48);
        final rows = <List<bool>>[];
        final controller = MealCalculatorRequestController(
          store: MemoryMealCalculatorRequestStore(),
          now: () => opened.add(async.elapsed),
          readContext: (_) async => null,
          projectExtendedConfirmation: (_, _, _, _) async {},
          publishWindow: (_, state) async => rows.add(state),
          onError: (error, _) => fail('$error'),
        );
        final container = ProviderContainer(
          overrides: [
            mealCalculatorRequestControllerProvider.overrideWithValue(
              controller,
            ),
            dataSourceConfigProvider.overrideWithValue(
              const AsyncData(
                DataSourceConfig(
                  bgSource: BgSource.aaps,
                  treatmentsSource: TreatmentsSource.aaps,
                  pumpStatusSource: PumpStatusSource.aaps,
                  historySource: HistorySource.local,
                  mirrorToLocal: false,
                ),
              ),
            ),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        final handler = ExternalEventHandler(harness.runtimeContext);

        handler.handle(
          CalculatorRequestCommand(
            event: const AapsBolusSuggestionNotificationEvent(
              mealId: 7,
              carbs: 31,
            ),
            sessionId: 'dash-31g',
            openedAt: opened,
          ).toExternalAppEventJson(),
        );
        async.flushMicrotasks();
        expect(rows.last, [false]);

        const wizardAt = '2026-11-23T18:48:19.824Z';
        final wizard = {
          'eventType': 'Bolus Wizard',
          'created_at': wizardAt,
          'date': DateTime.parse(wizardAt).millisecondsSinceEpoch,
          'isValid': true,
          'glucose': 136.0,
          'units': 'mg/dl',
          'bolusCalculatorResult': jsonEncode({
            'carbs': 31.0,
            'totalInsulin': 2.0,
            'timestamp': DateTime.parse(wizardAt).millisecondsSinceEpoch,
            'wereCarbsUsed': false,
          }),
        };
        CalculatorSubmission submission() =>
            container.read(calculatorSubmissionsProvider).single;
        if (!scenario.bolusFirst) {
          async.elapse(const Duration(seconds: 31, milliseconds: 842));
          handler.handle(broadcast([wizard]));
          async.elapse(const Duration(seconds: 1));
          expect(rows.last, [true]);
          expect(submission().deliveredInsulin, isNull);
        }

        const bolusAt = '2026-11-23T18:48:25.834Z';
        final start = {
          'eventType': 'Meal Bolus',
          'created_at': bolusAt,
          'date': DateTime.parse(bolusAt).millisecondsSinceEpoch,
          'isValid': true,
          'insulin': 2.0,
          'type': 'NORMAL',
          'isSMB': false,
          'pumpId': 15,
          'pumpType': 'OMNIPOD_DASH',
          'pumpSerial': 'test-pod',
        };
        const startAfterOpening = Duration(seconds: 37, milliseconds: 924);
        async.elapse(startAfterOpening - async.elapsed);
        final pumpStartedAt = async.elapsed;
        handler.handle(broadcast([start]));
        async.elapse(const Duration(seconds: 1));
        if (!scenario.bolusFirst) {
          expect(submission().deliveredInsulin, 2.0);
          expect(submission().wizard.carbohydrateRecord, isNull);
        }

        // The xDrip-compatible broadcast can repeat the start record after NS ACK.
        async.elapse(const Duration(seconds: 10));
        if (scenario.bolusFirst) {
          expect(rows.last, [false]);
          expect(container.read(calculatorSubmissionsProvider), isEmpty);
          handler.handle(broadcast([wizard]));
          async.elapse(const Duration(seconds: 1));
          expect(rows.last, [true]);
          expect(submission().deliveredInsulin, 2.0);
        }
        final repeated = {...start, '_id': 'test-ns-bolus'};
        handler.handle(broadcast(repeated));
        async.elapse(const Duration(seconds: 1));
        expect(submission().deliveredInsulin, 2.0);

        // AAPS writes carbs after CommandBolus returns, with their original time.
        async.elapse(
          pumpStartedAt + const Duration(seconds: 59) - async.elapsed,
        );
        expect(rows.last, [true]);
        expect(submission().isComplete, isTrue);
        expect(submission().deliveredInsulin, 2.0);
        expect(submission().wizard.carbohydrateRecord, isNull);

        async.elapse(const Duration(seconds: 1));
        expect(async.elapsed - pumpStartedAt, const Duration(minutes: 1));
        const carbsAt = '2026-11-23T18:48:17.755Z';
        handler.handle(
          broadcast([
            if (scenario.stopped) {...repeated, 'insulin': 1.5},
            {
              'eventType': 'Meal Bolus',
              'created_at': carbsAt,
              'date': DateTime.parse(carbsAt).millisecondsSinceEpoch,
              'isValid': true,
              'carbs': 31.0,
            },
          ]),
        );
        async.elapse(const Duration(seconds: 1));

        expect(rows.last, [true]);
        expect(submission().wizard.carbohydrateRecord?.carbs, 31);
        expect(submission().recommendedInsulin, 2.0);
        expect(submission().deliveredInsulin, scenario.stopped ? 1.5 : 2.0);
        expect(
          submission().delivery?.createdAt.toUtc(),
          DateTime.parse(bolusAt),
        );
        expect(async.pendingTimers, isEmpty);

        controller.dispose();
        harness.dispose();
        async.flushMicrotasks();
      });
    });
  }

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

Map<String, dynamic> broadcast(Object record) => {
  'external_event': 'native_receiver',
  'data': {
    'kind': 'treatments',
    'data': {'data': record},
  },
};
