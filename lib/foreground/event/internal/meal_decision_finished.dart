import '../../../common/events/data/app_event_data.dart';
import '../model/foreground_event.dart';

/// A meal decision was accepted or rejected outside the advisor offer, e.g.
/// from a caregiver answer or a manual choice. The monitor drops the stale
/// advisor offer and re-evaluates the saved plan.
class MealDecisionFinished extends ForegroundEvent with AppEventData {
  const MealDecisionFinished(this.mealId);

  static const command = 'meal_decision_finished';
  final int mealId;

  @override
  String get eventName => command;

  @override
  Map<String, dynamic> toJson() => {'mealId': mealId};
}
