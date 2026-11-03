import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final opened = DateTime(2026, 11, 3, 12);
  const event = AapsBolusSuggestionNotificationEvent(mealId: 7, carbs: 30);
  final evidence = <String, dynamic>{
    'submissions': [
      {
        'at': opened.add(const Duration(seconds: 10)).millisecondsSinceEpoch,
        'carbs': 30,
        'valid': true,
        'complete': true,
      },
    ],
  };

  test(
    'cancelling the meal dismisses the window without checking unfinished actions',
    () async {
      var relevant = true;
      final closed = <String>[];
      final rows = <List<bool>>[];
      final store = MemoryMealCalculatorRequestStore();
      final controller = MealCalculatorRequestController(
        store: store,
        now: () => opened,
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        isMealRelevant: (_) async => relevant,
        closeWindow: (id) async {
          closed.add(id);
        },
        publishWindow: (_, value) async {
          rows.add(value);
        },
        onError: (error, _) => fail('$error'),
      );
      await controller.register(event, sessionId: 'pip-1');
      relevant = false;
      await controller.refresh();
      expect(closed, ['pip-1']);
      expect(rows, [
        [false],
      ]);
      expect(store.requests, isEmpty);
    },
  );

  test(
    'notification cleanup failures never prevent completed checkmarks',
    () async {
      var cleanups = 0;
      final errors = <Object>[];
      final rows = <List<bool>>[];
      final controller = MealCalculatorRequestController(
        store: MemoryMealCalculatorRequestStore(),
        now: () => opened,
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        publishWindow: (_, value) async {
          rows.add(value);
        },
        onComplete: (_) async {
          cleanups++;
          if (cleanups == 1) throw StateError('Notification unavailable');
        },
        onError: (error, _) {
          errors.add(error);
        },
      );
      await controller.register(event, sessionId: 'pip-1');
      await controller.observe(evidence);
      expect(rows.last, [true]);
      expect(errors, hasLength(1));
      await controller.refresh();
      expect(cleanups, 2);
      await controller.refresh();
      expect(cleanups, 2);
    },
  );

  test(
    'an extended record observed before the current request cannot satisfy it',
    () async {
      var now = opened.subtract(const Duration(minutes: 1));
      final rows = <List<bool>>[];
      final controller = MealCalculatorRequestController(
        store: MemoryMealCalculatorRequestStore(),
        now: () => now,
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        publishWindow: (_, value) async {
          rows.add(value);
        },
        onError: (error, _) => fail('$error'),
      );
      final extendedEvidence = <String, dynamic>{
        ...evidence,
        'extendedCarb': {
          'id': 'old-record',
          'at': opened
              .add(const Duration(minutes: 45, seconds: 10))
              .millisecondsSinceEpoch,
          'carbs': 15,
          'duration': const Duration(hours: 2).inMilliseconds,
          'valid': true,
        },
      };
      await controller.observe(extendedEvidence);
      now = opened;
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
      expect(rows.last, [true, false, false]);
      await controller.observe(extendedEvidence);
      expect(rows.last, [true, false, false]);
    },
  );
}
