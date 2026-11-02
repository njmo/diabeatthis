import 'dart:async';

import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_progress_plan.dart';
import 'package:diabeatthis/common/widgets/meal_progress/meal_progress_step.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_add_on_bolus_context_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_progress/active_meal_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

MealAddOnBolusContext progressAddOn({
  String originalStatus = 'eating-then-bolus',
  bool bolusConfirmed = false,
  bool awaitingBolus = true,
}) => MealAddOnBolusContext(
  originalStatus: originalStatus,
  eatingStartedAt: DateTime(2026, 11, 2, 12),
  requestedAt: DateTime(2026, 11, 2, 12, 15),
  coveredCarbs: bolusConfirmed ? 30 : 0,
  statusCoveredCarbs: bolusConfirmed ? 30 : 0,
  reportedExtendedCarbs: 0,
  requestedCarbs: awaitingBolus ? 5 : 0,
  requestedExtendedCarbs: 0,
  awaitingBolus: awaitingBolus,
  bolusConfirmed: bolusConfirmed,
);

void main() {
  test(
    'an eating-first add-on is current without falsely confirming its bolus',
    () {
      final plan = mealProgressPlanForStatus(
        'eating-extra',
        addOn: progressAddOn(),
      );

      expect(plan.stages, [
        MealProgressStage.eating,
        MealProgressStage.bolus,
        MealProgressStage.extra,
      ]);
      expect(plan.currentIndex, 2);
      expect(plan.isComplete(0), isTrue);
      expect(plan.isComplete(1), isFalse);
    },
  );

  test('a pending add-on retains an already confirmed original bolus', () {
    final plan = mealProgressPlanForStatus(
      'eating-extra',
      addOn: progressAddOn(bolusConfirmed: true),
    );

    expect(plan.currentIndex, 2);
    expect(plan.isComplete(1), isTrue);
    expect(plan.pendingIndices, isEmpty);
  });

  test('bolus then waiting retains its stages before the current add-on', () {
    final plan = mealProgressPlanForStatus(
      'eating-extra',
      addOn: progressAddOn(
        originalStatus: 'waited-eating',
        bolusConfirmed: true,
      ),
    );

    expect(plan.stages, [
      MealProgressStage.bolus,
      MealProgressStage.waiting,
      MealProgressStage.eating,
      MealProgressStage.extra,
    ]);
    expect(plan.currentIndex, 3);
    expect(plan.isComplete(0), isTrue);
  });

  test('manual eating adds no invented bolus stage', () {
    final plan = mealProgressPlanForStatus(
      'eating-extra',
      addOn: progressAddOn(originalStatus: 'eating', awaitingBolus: false),
    );

    expect(plan.stages, [MealProgressStage.eating, MealProgressStage.extra]);
    expect(plan.currentIndex, 1);
  });

  test('finished actual food puts the remaining bolus after its add-on', () {
    final plan = mealProgressPlanForStatus(
      'waiting-for-bolus',
      addOn: progressAddOn(bolusConfirmed: true),
    );

    expect(plan.stages, [
      MealProgressStage.eating,
      MealProgressStage.extra,
      MealProgressStage.bolus,
    ]);
    expect(plan.currentIndex, 2);
    expect(plan.isComplete(1), isTrue);
    expect(plan.isComplete(2), isFalse);
  });

  testWidgets(
    'a durable confirmation updates the checkmark without changing eating-extra status',
    (tester) async {
      final changes = StreamController<MealAddOnBolusContext?>();
      addTearDown(changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealAddOnBolusContextProvider(
              1,
            ).overrideWith((ref) => changes.stream),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(
              body: ActiveMealSteps(
                meal: Meal(id: 1, name: 'Meal', status: 'eating-extra'),
              ),
            ),
          ),
        ),
      );
      changes.add(progressAddOn());
      await tester.pumpAndSettle();
      var steps = tester
          .widgetList<MealProgressStep>(find.byType(MealProgressStep))
          .toList();
      expect(steps, hasLength(3));
      expect(steps[1].complete, isFalse);
      expect(steps[2].current, isTrue);

      changes.add(progressAddOn(bolusConfirmed: true, awaitingBolus: false));
      await tester.pumpAndSettle();
      steps = tester
          .widgetList<MealProgressStep>(find.byType(MealProgressStep))
          .toList();
      expect(steps[1].complete, isTrue);
      expect(steps[2].current, isTrue);
    },
  );
}
