import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_answer.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_decision_demo_controller_test.dart' show demoContainer;

void main() {
  test(
    'only the caregiver who claims the current request can answer it',
    () async {
      final container = demoContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        mealDecisionDemoControllerProvider.notifier,
      );
      await controller.send('meal', 'Lunch');
      final request = container.read(
        mealDecisionDemoControllerProvider,
      )['meal']!;
      expect(controller.claim('meal', 'stale', 'Anna'), isFalse);
      expect(controller.claim('meal', request.id, 'Anna'), isTrue);
      expect(controller.claim('meal', request.id, 'Anna'), isTrue);
      expect(
        controller.claim('meal', request.id, 'Adam', caregiverId: 'demo-other'),
        isFalse,
      );
      expect(
        container.read(mealDecisionDemoControllerProvider)['meal']!.claimedBy,
        'Anna',
      );
      expect(
        controller.respond(
          'meal',
          request.id,
          answer: MealDecisionDemoAnswer.insulinAndEat,
          minutes: 0,
          caregiverName: 'Adam',
          caregiverId: 'demo-other',
        ),
        isFalse,
      );
      expect(
        controller.respond(
          'meal',
          request.id,
          answer: MealDecisionDemoAnswer.insulinAndEat,
          minutes: 0,
          caregiverName: 'Anna',
        ),
        isTrue,
      );
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverName,
        'Anna',
      );
      expect(controller.acknowledge('meal', request.id), isTrue);
      final accepted = container
          .read(mealDecisionDemoControllerProvider)['meal']!
          .acceptedAdvice!;
      expect(accepted.source, 'caregiver');
      expect(accepted.caregiverId, 'demo-caregiver');
      expect(accepted.decision, MealDecisionDemoAnswer.insulinAndEat.decision);
    },
  );
}
