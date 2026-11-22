import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../meal_decision_preferences.dart';
import 'meal_decision_remote_request.dart';

class MealDecisionResolution {
  const MealDecisionResolution({
    this.advice,
    this.fallback,
    this.request,
    this.deferred = false,
    this.rejected = false,
    this.acceptanceToken,
  });
  final MealAdvice? advice;
  final MealDecisionTimeoutFallback? fallback;
  final MealDecisionRemoteRequest? request;
  final bool deferred;
  final bool rejected;
  final String? acceptanceToken;
}
