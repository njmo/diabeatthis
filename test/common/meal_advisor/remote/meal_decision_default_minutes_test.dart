import 'package:diabeatthis/common/meal_advisor/meal_decision_answer.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_default_minutes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insulin waiting does not inherit the configured meal deferral', () {
    for (final configured in [30, 45, 60]) {
      expect(
        mealDecisionDefaultMinutes(
          MealDecisionAnswer.insulinThenWait,
          deferralMinutes: configured,
        ),
        10,
      );
      expect(
        mealDecisionDefaultMinutes(
          MealDecisionAnswer.deferMeal,
          deferralMinutes: configured,
        ),
        configured,
      );
    }
  });
  test('immediate decisions have no waiting period', () {
    for (final answer in [
      MealDecisionAnswer.insulinAndEat,
      MealDecisionAnswer.eatThenInsulin,
    ]) {
      expect(mealDecisionDefaultMinutes(answer, deferralMinutes: 45), 0);
    }
  });
}
