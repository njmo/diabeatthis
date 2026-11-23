import '../../../common/events/data/app_event_data.dart';
import '../model/foreground_event.dart';

class MealBolusContinuedManually extends ForegroundEvent with AppEventData {
  const MealBolusContinuedManually(this.mealId);

  static const command = 'meal_bolus_continued_manually';
  final int mealId;

  @override
  String get eventName => command;

  @override
  Map<String, dynamic> toJson() => {'mealId': mealId};
}
