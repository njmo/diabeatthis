import 'package:diabeatthis/common/meal/calculator/calculator_request_command.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller_provider.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
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
}
