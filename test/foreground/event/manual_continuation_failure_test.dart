import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller_provider.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/meal_bolus_continued_manually.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

class _FailingController extends MealCalculatorRequestController {
  _FailingController()
    : super(
        store: MemoryMealCalculatorRequestStore(),
        publishWindow: (_, _) async {},
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        onError: (_, _) {},
      );

  @override
  Future<void> dismissAfterManualContinuation(int mealId) async =>
      throw StateError('store unavailable');
}

void main() {
  test(
    'manual continuation still continues the meal when cleanup fails',
    () async {
      final controller = _FailingController();
      final container = ProviderContainer(
        overrides: [
          mealCalculatorRequestControllerProvider.overrideWithValue(controller),
        ],
      );
      addTearDown(() {
        controller.dispose();
        container.dispose();
      });
      final harness = FakeRuntimeHarness(container: container);

      ExternalEventHandler(
        harness.runtimeContext,
      ).handle(const MealBolusContinuedManually(5).toExternalAppEventJson());
      await pumpEventQueue();

      final continued = harness.emittedEvents
          .whereType<MealBolusContinuedManually>()
          .single;
      expect(continued.mealId, 5);
    },
  );
}
