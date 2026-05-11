import '../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class MealSuggestionNotificationEvent implements NotificationEvent {
  MealSuggestionNotificationEvent({
    required this.mealId,
    required this.minutes,
    required this.decision,
    required this.carbs,
    this.isAddOn = false,
  });

  final int mealId;
  final MealDecision decision;
  final int minutes;
  final int carbs;
  final bool isAddOn;

  @override
  NotificationEventType get type => NotificationEventType.mealSuggestion;

  @override
  String get notificationResponseEvent => 'meal_suggestion_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title =>
      isAddOn ? 'Dokładka: wpisz w AAPS' : 'Sugestia odnośnie posiłku';

  @override
  String get body {
    if (isAddOn) {
      if (carbs > 0) {
        return 'Nie widzę dodatkowego wpisu z AAPS. Wpisz +$carbs g węglowodanów za dokładkę.';
      }
      return 'Nie widzę dodatkowego wpisu z AAPS. Wpisz węglowodany za dokładkę.';
    }

    switch (decision) {
      case MealDecision.eatNowBolusLater:
        return 'Zjedz teraz a insuline podaj po posiłku';
      case MealDecision.bolusAndEatNow:
        return 'Podaj insuline na $carbs g odnośnie posiłku i jedz teraz';
      case MealDecision.bolusWaitThenEat:
        return 'Podaj insuline na $carbs g odnośnie posiłku i czekaj $minutes minut przed jedzeniem';
      case MealDecision.bolus:
        return 'Podaj insuline na $carbs g odnośnie zjedzonego posiłku';
    }
  }

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'mealId': mealId},
  };

  @override
  Map<String, Object?> toJson() => {
    'mealId': mealId,
    'minutes': minutes,
    'carbs': carbs,
    'decision': decision.index,
    'isAddOn': isAddOn,
  };

  factory MealSuggestionNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return MealSuggestionNotificationEvent(
      mealId: json['mealId'] as int,
      minutes: json['minutes'] as int,
      carbs: json['carbs'] as int,
      decision: MealDecision.values[json['decision'] as int],
      isAddOn: json['isAddOn'] as bool? ?? false,
    );
  }
}
