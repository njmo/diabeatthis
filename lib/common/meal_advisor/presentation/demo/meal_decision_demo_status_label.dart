import 'package:flutter/widgets.dart';

import '../../../l10n/language.dart';
import '../../demo/meal_decision_demo_request.dart';

String mealDecisionDemoStatusLabel(
  BuildContext context,
  MealDecisionDemoStatus status,
) => switch (status) {
  MealDecisionDemoStatus.timedOut => context.lang.mealDecisionTimeoutWaiting,
  MealDecisionDemoStatus.sending => context.lang.mealDecisionDemoSending,
  MealDecisionDemoStatus.waiting => context.lang.mealDecisionDemoWaiting,
  MealDecisionDemoStatus.answered => context.lang.mealDecisionDemoAnswered,
  MealDecisionDemoStatus.accepted => context.lang.mealDecisionDemoAccepted,
};

String mealDecisionDemoRequestLabel(
  BuildContext context,
  MealDecisionDemoRequest request,
) =>
    request.status == MealDecisionDemoStatus.timedOut &&
        request.fallbackAdvice != null
    ? context.lang.mealDecisionTimeoutDecisionReady
    : mealDecisionDemoStatusLabel(context, request.status);
