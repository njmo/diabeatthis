import '../meal_decision_answer.dart';

/// Deferring the meal and waiting after insulin are independent choices.
int mealDecisionDefaultMinutes(
  MealDecisionAnswer answer, {
  required int deferralMinutes,
}) => switch (answer) {
  MealDecisionAnswer.deferMeal => deferralMinutes,
  MealDecisionAnswer.insulinThenWait => 10,
  _ => 0,
};
