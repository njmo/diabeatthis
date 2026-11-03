import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a background carbs-only reminder cannot drop the active PiP e-carbs requirement',
    () async {
      final started = DateTime(2026, 11, 3, 12);
      final wizardAt = started.add(const Duration(seconds: 10));
      final windows = <List<bool>>[];
      final controller = MealCalculatorRequestController(
        store: MemoryMealCalculatorRequestStore(),
        now: () => started,
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        publishWindow: (_, rows) async {
          windows.add(rows);
        },
        onError: (error, _) => fail('$error'),
      );
      await controller.register(
        const AapsBolusSuggestionNotificationEvent(
          mealId: 7,
          carbs: 30,
          extendedCarbs: 15,
          extendedCarbsDelayMinutes: 45,
          extendedCarbsDurationMinutes: 120,
        ),
        sessionId: 'pip-1',
      );
      await controller.register(
        const AapsBolusSuggestionNotificationEvent(mealId: 7, carbs: 30),
      );
      final submissions = [
        {
          'at': wizardAt.millisecondsSinceEpoch,
          'carbs': 30,
          'valid': true,
          'complete': true,
        },
      ];
      await controller.observe({'submissions': submissions});
      expect(windows.last, [true, false, false]);
      await controller.observe({
        'submissions': submissions,
        'extendedCarb': {
          'id': 'extended-1',
          'at': wizardAt
              .add(const Duration(minutes: 45))
              .millisecondsSinceEpoch,
          'carbs': 15,
          'duration': const Duration(hours: 2).inMilliseconds,
          'valid': true,
        },
      });
      expect(windows.last, [true, true, true]);
    },
  );
}
