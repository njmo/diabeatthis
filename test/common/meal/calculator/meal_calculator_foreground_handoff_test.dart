import 'package:diabeatthis/common/meal/calculator/calculator_evidence_snapshot.dart';
import 'package:diabeatthis/common/meal/calculator/calculator_request_command.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_entries_provider.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller_provider.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_runtime_harness.dart';

void main() {
  test(
    'UI command and foreground correction update one owner while preserving treatment events',
    () async {
      final opened = DateTime(2026, 11, 3, 13, 18);
      final rows = <List<bool>>[];
      final owner = MealCalculatorRequestController(
        store: MemoryMealCalculatorRequestStore(),
        now: () => opened,
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        publishWindow: (session, state) async {
          expect(session, 'ui-session');
          rows.add(state);
        },
        onError: (error, _) => fail('$error'),
      );
      final container = ProviderContainer(
        overrides: [
          mealCalculatorRequestControllerProvider.overrideWithValue(owner),
        ],
      );
      addTearDown(() {
        owner.dispose();
        container.dispose();
      });
      final harness = FakeRuntimeHarness(container: container);
      ExternalEventHandler(harness.runtimeContext).handle(
        CalculatorRequestCommand(
          event: const AapsBolusSuggestionNotificationEvent(
            mealId: 7,
            carbs: -2,
          ),
          sessionId: 'ui-session',
          openedAt: opened,
        ).toExternalAppEventJson(),
      );
      await owner.refresh();
      expect(rows.last, [false]);
      final correction = Treat(
        externalId: 'correction',
        createdAt: opened.add(const Duration(seconds: 13)),
        carbs: -2,
      );
      TreatmentEventDispatcher().dispatch(
        container: container,
        emitEvent: harness.runtimeContext.emitEvent,
        treatment: correction,
      );
      await owner.refresh();
      expect(rows.last, [true]);
      expect(
        harness.emittedEvents
            .whereType<TreatmentAvailableEvent<Treat>>()
            .single
            .data,
        correction,
      );
      TreatmentEventDispatcher().dispatch(
        container: container,
        emitEvent: harness.runtimeContext.emitEvent,
        treatment: correction.copyWith(isValid: false),
      );
      await owner.refresh();
      expect(rows.last, [false]);
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<Treat>>(),
        hasLength(1),
      );
    },
  );
  const receiptScenarios = [
    (name: 'missing calculator', wizard: false, delivery: true, late: false),
    (name: 'missing delivery', wizard: true, delivery: false, late: false),
    (name: 'complete submission', wizard: true, delivery: true, late: false),
    (
      name: 'delayed smaller delivery',
      wizard: true,
      delivery: true,
      late: true,
    ),
  ];
  for (final scenario in receiptScenarios) {
    test('AAPS PiP with late 31 g and ${scenario.name}', () async {
      final opened = DateTime.utc(2026, 11, 23, 18, 47, 48);
      var now = opened;
      final store = MemoryMealCalculatorRequestStore();
      final entryChanges = <Set<int>>[];
      final rows = <List<bool>>[];
      final owner = MealCalculatorRequestController(
        store: store,
        onEntriesChanged: () => entryChanges.add(
          recordedMealCalculatorEntries(
            store.requests.map(MealCalculatorRequest.fromJson),
          ),
        ),
        now: () => now,
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        publishWindow: (_, state) async => rows.add(state),
        onError: (error, _) => fail('$error'),
      );
      final container = ProviderContainer(
        overrides: [
          mealCalculatorRequestControllerProvider.overrideWithValue(owner),
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
      addTearDown(() {
        owner.dispose();
        container.dispose();
      });
      final harness = FakeRuntimeHarness(container: container);
      final handler = ExternalEventHandler(harness.runtimeContext);
      Future<void> receive(
        Map<String, dynamic> record,
        DateTime arrival,
      ) async {
        now = arrival;
        handler.handle({
          'external_event': 'native_receiver',
          'data': {
            'kind': 'treatments',
            'data': {'data': record},
          },
        });
        await handler.flushPendingTreatments();
        await owner.refresh();
      }

      handler.handle(
        CalculatorRequestCommand(
          event: const AapsBolusSuggestionNotificationEvent(
            mealId: 7,
            carbs: 31,
          ),
          sessionId: 'pip-31g',
          openedAt: opened,
        ).toExternalAppEventJson(),
      );
      await owner.refresh();
      expect(rows.last, [false]);

      if (scenario.wizard) {
        await receive({
          'eventType': 'Bolus Wizard',
          'created_at': '2026-11-23T18:48:19.824Z',
          'glucose': 136,
          'isValid': true,
          'carbs': null,
          'insulin': null,
          'bolusCalculatorResult':
              '{"carbs":31.0,"totalInsulin":2.0,"wereCarbsUsed":false}',
        }, DateTime.utc(2026, 11, 23, 18, 48, 20, 162));
        expect(rows.last, [true]);
      }

      Future<void> receiveDelivery(double units, DateTime arrival) => receive({
        'eventType': 'Meal Bolus',
        'created_at': '2026-11-23T18:48:25.834Z',
        'isValid': true,
        'carbs': null,
        'insulin': units,
      }, arrival);

      if (scenario.delivery && !scenario.late) {
        await receiveDelivery(2, DateTime.utc(2026, 11, 23, 18, 48, 26, 277));
        expect(rows.last, [scenario.wizard]);
      }

      await receive({
        'eventType': 'Meal Bolus',
        'created_at': '2026-11-23T18:48:17.755Z',
        'isValid': true,
        'carbs': 31,
        'insulin': null,
      }, DateTime.utc(2026, 11, 23, 18, 49, 50, 502));

      final standaloneCarbs = harness.emittedEvents
          .whereType<TreatmentAvailableEvent<Treat>>();
      if (scenario.wizard) {
        expect(standaloneCarbs, isEmpty);
        expect(
          container
              .read(calculatorSubmissionsProvider)
              .single
              .wizard
              .carbohydrateRecord
              ?.carbs,
          31,
        );
      } else {
        expect(standaloneCarbs.single.data.carbs, 31);
      }
      if (scenario.late) {
        expect(rows.last, [true]);
        await receiveDelivery(1.5, DateTime.utc(2026, 11, 23, 18, 49, 51));
        final snapshot = CalculatorEvidenceSnapshot(
          container.read(calculatorSubmissionsProvider),
          null,
        ).toJson();
        expect(snapshot['submissions'], [
          containsPair('recommendedInsulin', 2.0),
        ]);
        expect(snapshot['submissions'], [
          containsPair('deliveredInsulin', 1.5),
        ]);
      }
      expect(rows.last, [scenario.wizard]);
      expect(
        entryChanges,
        scenario.wizard
            ? [
                {7},
              ]
            : isEmpty,
      );
    });
  }
}
