import 'package:clock/clock.dart';

import '../../../../common/meal/meal_decision.dart';
import '../utils/wbt_extended_carbs_calculator.dart';
import 'meal_activity_dose_suggestion.dart';
import 'meal_advice_reason.dart';
import 'wait_suggestion.dart';

class MealAdvice {
  final MealActivityDoseSuggestion? activityDoseSuggestion;
  final MealDecision? decision;
  final MealAdviceReason? reason;
  final String source;
  final WaitSuggestion? wait;
  final WbtExtendedCarbsSuggestion extendedCarbs;
  final DateTime createdAt;

  MealAdvice(
    this.decision,
    this.wait, {
    this.source = 'mealAdvisor',
    this.activityDoseSuggestion,
    this.reason,
    WbtExtendedCarbsSuggestion? extendedCarbs,
  }) : extendedCarbs = extendedCarbs ?? const WbtExtendedCarbsSuggestion.none(),
       createdAt = clock.now();

  MealAdvice.full(
    this.decision,
    this.wait,
    this.createdAt, {
    this.source = 'mealAdvisor',
    this.activityDoseSuggestion,
    this.reason,
    WbtExtendedCarbsSuggestion? extendedCarbs,
  }) : extendedCarbs = extendedCarbs ?? const WbtExtendedCarbsSuggestion.none();

  MealAdvice.empty()
    : activityDoseSuggestion = null,
      reason = null,
      source = 'mealAdvisor',
      decision = null,
      wait = null,
      extendedCarbs = const WbtExtendedCarbsSuggestion.none(),
      createdAt = clock.now();
}
