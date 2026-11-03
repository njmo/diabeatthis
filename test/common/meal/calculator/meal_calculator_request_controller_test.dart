import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final opened = DateTime(2026, 11, 3, 12);
  final wizardAt = opened.add(const Duration(seconds: 10));
  const event = AapsBolusSuggestionNotificationEvent(
    mealId: 7,
    carbs: 30,
    extendedCarbs: 15,
    extendedCarbsDelayMinutes: 45,
    extendedCarbsDurationMinutes: 120,
  );

  Map<String, dynamic> evidence({bool extended = false, bool valid = true}) => {
    'submissions': [
      {
        'at': wizardAt.millisecondsSinceEpoch,
        'carbs': 30,
        'valid': true,
        'complete': true,
      },
    ],
    if (extended)
      'extendedCarb': {
        'id': 'extended-1',
        'at': wizardAt.add(const Duration(minutes: 45)).millisecondsSinceEpoch,
        'carbs': 15,
        'duration': const Duration(hours: 2).inMilliseconds,
        'valid': valid,
      },
  };

  MealAddOnBolusContext pending() => MealAddOnBolusContext(
    originalStatus: 'eating-extra',
    eatingStartedAt: opened,
    requestedAt: opened,
    coveredCarbs: 0,
    statusCoveredCarbs: 0,
    reportedExtendedCarbs: 15,
    requestedCarbs: 30,
    requestedExtendedCarbs: 15,
    awaitingBolus: true,
    bolusConfirmed: false,
  );

  test(
    'the card and PiP observe the same accepted bolus and extended confirmation',
    () async {
      var context = pending();
      final windows = <List<bool>>[];
      final controller = MealCalculatorRequestController(
        now: () => opened.add(const Duration(seconds: 20)),
        store: MemoryMealCalculatorRequestStore(),
        publishWindow: (_, rows) async {
          windows.add(rows);
        },
        readContext: (_) async => context,
        projectExtendedConfirmation: (_, at, grams, confirmed) async {
          expect(at, context.requestedAt);
          expect(grams, 15);
          context = context.copyWith(extendedCarbsConfirmed: confirmed);
        },
        onError: (error, _) => fail('$error'),
      );
      await withClock(
        Clock.fixed(opened),
        () => controller.register(event, sessionId: 'pip-1'),
      );
      await controller.observe(evidence());
      expect(windows.last, [false, false, false]);
      context = context.copyWith(
        awaitingBolus: false,
        bolusConfirmed: true,
        requestedCarbs: 0,
        acceptedWizardKeys: ['at:${wizardAt.millisecondsSinceEpoch}'],
      );
      await controller.refresh();
      expect(windows.last, [true, false, false]);
      expect(context.showCalculatorAction, isTrue);
      await controller.observe(evidence(extended: true));
      expect(windows.last, [true, true, true]);
      expect(context.showCalculatorAction, isFalse);
    },
  );

  test(
    'extended carbs can be checked before the meal accepts its bolus',
    () async {
      var context = pending();
      final windows = <List<bool>>[];
      final controller = MealCalculatorRequestController(
        now: () => opened.add(const Duration(seconds: 20)),
        store: MemoryMealCalculatorRequestStore(),
        publishWindow: (_, rows) async {
          windows.add(rows);
        },
        readContext: (_) async => context,
        projectExtendedConfirmation: (_, _, _, confirmed) async {
          context = context.copyWith(extendedCarbsConfirmed: confirmed);
        },
        onError: (error, _) => fail('$error'),
      );
      await withClock(
        Clock.fixed(opened),
        () => controller.register(event, sessionId: 'pip-1'),
      );
      await controller.observe(evidence(extended: true));
      expect(windows.last, [false, true, true]);
      expect(context.showCalculatorAction, isTrue);
      context = context.copyWith(
        awaitingBolus: false,
        bolusConfirmed: true,
        requestedCarbs: 0,
      );
      await controller.refresh();
      expect(windows.last, [true, true, true]);
      expect(context.showCalculatorAction, isFalse);
    },
  );

  test(
    'foreground restart restores evidence and an invalidation unchecks the item',
    () async {
      var context = pending();
      final store = MemoryMealCalculatorRequestStore();
      final windows = <List<bool>>[];
      MealCalculatorRequestController create() =>
          MealCalculatorRequestController(
            now: () => opened.add(const Duration(seconds: 20)),
            store: store,
            publishWindow: (_, rows) async {
              windows.add(rows);
            },
            readContext: (_) async => context,
            projectExtendedConfirmation: (_, _, _, confirmed) async {
              context = context.copyWith(extendedCarbsConfirmed: confirmed);
            },
            onError: (error, _) => fail('$error'),
          );
      final first = create();
      await withClock(
        Clock.fixed(opened),
        () => first.register(event, sessionId: 'pip-1'),
      );
      await first.observe(evidence(extended: true));
      first.dispose();
      final restored = create();
      await restored.refresh();
      expect(windows.last, [false, true, true]);
      await restored.observe(evidence(extended: true, valid: false));
      expect(windows.last, [false, false, false]);
      expect(context.extendedCarbsConfirmed, isFalse);
    },
  );

  test('a newer meal request is never mutated by old evidence', () async {
    var context = pending();
    var writes = 0;
    final windows = <List<bool>>[];
    final controller = MealCalculatorRequestController(
      now: () => opened.add(const Duration(seconds: 20)),
      store: MemoryMealCalculatorRequestStore(),
      publishWindow: (_, rows) async {
        windows.add(rows);
      },
      readContext: (_) async => context,
      projectExtendedConfirmation: (_, _, _, _) async {
        writes++;
      },
      onError: (error, _) => fail('$error'),
    );
    await withClock(
      Clock.fixed(opened),
      () => controller.register(event, sessionId: 'old'),
    );
    final previousWrites = writes;
    context = context.copyWith(
      requestedAt: opened.add(const Duration(minutes: 5)),
    );
    await controller.observe(evidence(extended: true));
    expect(writes, previousWrites);
    expect(windows, [
      [false, false, false],
    ]);
  });
}
