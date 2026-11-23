import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_evidence.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request.dart';
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

  test(
    'calculator confirmations are scoped to the meal and add-on timestamp',
    () {
      final base = MealCalculatorRequest(event: event, openedAt: opened);
      final addOn = MealCalculatorRequest(
        event: event,
        openedAt: opened,
        contextRequestedAt: opened,
      );
      expect(base.matchesMealStage(7, null), isTrue);
      expect(base.matchesMealStage(7, opened), isFalse);
      expect(addOn.matchesMealStage(7, opened), isTrue);
      expect(
        addOn.matchesMealStage(7, opened.add(const Duration(seconds: 1))),
        isFalse,
      );
      expect(addOn.matchesMealStage(8, opened), isFalse);
    },
  );

  test('calculator entry, delivery and scheduled eCarbs are distinct', () {
    final tracker = MealCalculatorEvidence(event: event, openedAt: opened);
    final submission = {
      'at': wizardAt.millisecondsSinceEpoch,
      'carbs': 30,
      'valid': true,
      'complete': false,
    };
    const duration = Duration(hours: 2);
    Map<String, Object> receipt(String id, DateTime at) => {
      'id': id,
      'at': at.millisecondsSinceEpoch,
      'carbs': 15,
      'duration': duration.inMilliseconds,
      'valid': true,
    };

    expect(
      tracker.update({
        'submissions': [submission],
        'extendedCarb': receipt('immediate', wizardAt),
      }),
      isFalse,
    );
    expect(tracker.carbsEntered, isTrue);
    expect(tracker.bolusConfirmed, isFalse);
    expect(tracker.extendedCarbsConfirmed, isFalse);

    final scheduled = wizardAt.add(const Duration(minutes: 45));
    expect(
      tracker.update({
        'submissions': [submission],
        'extendedCarb': receipt('scheduled', scheduled),
      }),
      isFalse,
    );
    expect(tracker.extendedCarbsConfirmed, isTrue);
    expect(tracker.bolusConfirmed, isFalse);
  });

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
    'PiP checks an earlier wizard once included in the request window',
    () async {
      final windows = <List<bool>>[];
      final earlierWizard = opened.subtract(const Duration(seconds: 2));
      final controller = MealCalculatorRequestController(
        now: () => opened,
        store: MemoryMealCalculatorRequestStore(),
        publishWindow: (_, rows) async => windows.add(rows),
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        onError: (error, _) => fail('$error'),
      );
      addTearDown(controller.dispose);
      await controller.register(event);
      await controller.observe({
        'submissions': [],
        'extendedCarb': {
          'id': 'early-extended',
          'at': earlierWizard
              .add(const Duration(minutes: 45))
              .millisecondsSinceEpoch,
          'carbs': event.extendedCarbs,
          'duration': const Duration(hours: 2).inMilliseconds,
          'valid': true,
        },
      });
      Map<String, Object> wizard({required bool delivered}) => {
        'at': earlierWizard.millisecondsSinceEpoch,
        'carbs': event.carbs,
        'valid': true,
        'complete': delivered,
      };
      // The wizard arrives before PiP opens, but delivery arrives afterwards.
      await controller.observe({
        'submissions': [wizard(delivered: false)],
      });
      await controller.register(event, sessionId: 'pip-early');
      expect(windows.last, [false, true, true]);

      await controller.register(
        event,
        openedAt: earlierWizard,
        refreshRequirements: true,
      );
      expect(windows.last, [true, true, true]);
      await controller.observe({
        'submissions': [wizard(delivered: true)],
      });
      expect(windows.last, [true, true, true]);
    },
  );

  test(
    'PiP acknowledges the calculator while the meal still awaits its bolus',
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
      expect(windows.last, [true, false, false]);
      expect(context.awaitingBolus, isTrue);
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
      await controller.observe({
        ...evidence(extended: true),
        'submissions': [],
      });
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
    'foreground restart restores checks and invalidations clear only their own rows',
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
      expect(windows.last, [true, true, true]);
      await restored.observe(evidence(extended: true, valid: false));
      expect(windows.last, [true, false, false]);
      await restored.observe({
        'submissions': [
          {
            'at': wizardAt.millisecondsSinceEpoch,
            'carbs': event.carbs,
            'valid': false,
            'complete': false,
          },
        ],
      });
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

  test('an add-on receipt cannot count as surplus for the main meal', () async {
    MealAddOnBolusContext? context;
    var surplus = 0;
    var now = wizardAt;
    final controller = MealCalculatorRequestController(
      now: () => now,
      store: MemoryMealCalculatorRequestStore(),
      publishWindow: (_, _) async {},
      readContext: (_) async => context,
      projectExtendedConfirmation: (_, _, _, _) async {},
      onTreatmentSurplus: (_) async {
        surplus++;
      },
      onError: (error, _) => fail('$error'),
    );
    await controller.register(event, openedAt: opened);
    await controller.observe(evidence(extended: true));
    now = now.add(const Duration(seconds: 20));
    context = pending().copyWith(requestedAt: now);
    final addOnEvidence = evidence(extended: true);
    addOnEvidence['extendedCarb']['id'] = 'extended-add-on';
    await controller.observe(addOnEvidence);
    expect(surplus, 0);
  });
}
