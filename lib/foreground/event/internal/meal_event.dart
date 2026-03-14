import '../model/foreground_event.dart';

class NextMealEvent extends ForegroundEvent
{
  final int mealId;

  NextMealEvent(this.mealId);
}