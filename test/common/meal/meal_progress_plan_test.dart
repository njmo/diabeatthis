import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_display_name.dart';
import 'package:diabeatthis/common/meal/meal_progress_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps eating before bolus when waiting follows eating', () {
    final plan = mealProgressPlanForStatus(
      'waiting-for-bolus',
      history: ['planned', 'eating-then-bolus', 'waiting-for-bolus'],
    );

    expect(plan.stages, [MealProgressStage.eating, MealProgressStage.bolus]);
    expect(plan.currentIndex, 1);
  });

  test('does not invent waiting when bolus and eating happen together', () {
    final plan = mealProgressPlanForStatus('bolused-eating');

    expect(plan.stages, [MealProgressStage.bolus, MealProgressStage.eating]);
    expect(plan.currentIndex, 1);
  });

  test('keeps waiting separate from eating after bolus', () {
    final plan = mealProgressPlanForStatus('bolused-waiting');

    expect(plan.stages, [
      MealProgressStage.bolus,
      MealProgressStage.waiting,
      MealProgressStage.eating,
    ]);
    expect(plan.currentIndex, 1);
  });

  test('uses the saved decision before the bolus has arrived', () {
    final plan = mealProgressPlanForStatus(
      'waiting-for-bolus',
      decision: MealDecision.bolusWaitThenEat,
    );

    expect(plan.stages.length, 3);
    expect(plan.currentIndex, 0);
  });

  test('unknown waiting decision shows only known bolus stage', () {
    final plan = mealProgressPlanForStatus('waiting-for-bolus');

    expect(plan.stages, [MealProgressStage.bolus]);
  });

  test('add-on preserves the previously recorded waiting path', () {
    final plan = mealProgressPlanForStatus(
      'eating-extra',
      history: ['bolused-waiting', 'waited-eating', 'eaten', 'eating-extra'],
    );

    expect(plan.stages.length, 3);
    expect(plan.currentIndex, 2);
  });

  test('quick meal display preserves the food name and stored marker', () {
    const storedName = 'QM: Owsianka';

    expect(isQuickMealName(storedName), isTrue);
    expect(mealDisplayName(storedName), 'Owsianka');
    expect(mealDisplayName('Kanapki'), 'Kanapki');
    expect(mealDisplayName('QM:'), isNotEmpty);
  });

  test(
    'add-on after an eating-first bolus does not mark bolus pending again',
    () {
      final plan = mealProgressPlanForStatus(
        'eating-extra',
        history: [
          'eating-then-bolus',
          'waiting-for-bolus',
          'eaten-bolused',
          'eating-extra',
        ],
      );

      expect(plan.stages, [
        MealProgressStage.eating,
        MealProgressStage.bolus,
        MealProgressStage.extra,
      ]);
      expect(plan.currentIndex, 2);
    },
  );
}
