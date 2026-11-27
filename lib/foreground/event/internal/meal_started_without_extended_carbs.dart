import '../../../common/events/data/app_event_data.dart';
import '../model/foreground_event.dart';

/// The child confirmed eating although the app has not matched the planned
/// eCarbs in AAPS yet (entered at another time, or not entered at all).
class MealStartedWithoutExtendedCarbs extends ForegroundEvent
    with AppEventData {
  const MealStartedWithoutExtendedCarbs(this.mealId);

  static const command = 'meal_started_without_extended_carbs';
  final int mealId;

  @override
  String get eventName => command;

  @override
  Map<String, dynamic> toJson() => {'mealId': mealId};
}
