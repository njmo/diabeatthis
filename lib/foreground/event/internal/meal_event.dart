import '../model/foreground_event.dart';

class NextMealEvent extends ForegroundEvent {
  final int mealId;
  final DateTime when;

  NextMealEvent(this.mealId, this.when);
}

/// Persistent storage currently has no planned meal candidate.
class PlannedMealsClearedEvent extends ForegroundEvent {}
