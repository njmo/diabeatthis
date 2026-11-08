import '../demo/meal_decision_demo_answer.dart';

/// Deferring the meal and waiting after insulin are independent choices.
int mealDecisionDefaultMinutes(
  MealDecisionDemoAnswer answer, {
  required int deferralMinutes,
}) => switch (answer) {
  MealDecisionDemoAnswer.deferMeal => deferralMinutes,
  MealDecisionDemoAnswer.insulinThenWait => 10,
  _ => 0,
};
