import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_decision_demo_controller_test.dart' show demoContainer;

void main() {
  test(
    'only the owner updates presence and the real context step; reopening restores presence',
    () async {
      final container = demoContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        mealDecisionDemoControllerProvider.notifier,
      );
      await controller.send('meal', 'Lunch');
      final id = container.read(mealDecisionDemoControllerProvider)['meal']!.id;
      controller.claim('meal', id, 'Anna');
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isTrue,
      );
      expect(
        container.read(mealDecisionDemoControllerProvider)['meal']!.stage,
        MealDecisionDemoStage.context,
      );
      expect(
        controller.updateCaregiverContext('meal', id, 'other', present: false),
        isFalse,
      );
      expect(
        controller.updateCaregiverContext(
          'meal',
          'old',
          'demo-caregiver',
          present: false,
        ),
        isFalse,
      );
      controller.updateCaregiverContext(
        'meal',
        id,
        'demo-caregiver',
        present: true,
        stage: MealDecisionDemoStage.decision,
      );
      expect(
        container.read(mealDecisionDemoControllerProvider)['meal']!.stage,
        MealDecisionDemoStage.decision,
      );
      controller.updateCaregiverContext(
        'meal',
        id,
        'demo-caregiver',
        present: false,
      );
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isFalse,
      );
      controller.claim('meal', id, 'Anna');
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isTrue,
      );
      expect(
        container.read(mealDecisionDemoControllerProvider)['meal']!.stage,
        MealDecisionDemoStage.context,
      );
    },
  );
}
