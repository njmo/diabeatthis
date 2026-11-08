import 'dart:async';

/// Prevents push taps from stacking a second copy of an already open request.
class MealDecisionPresentationRegistry {
  static final changes = StreamController<void>.broadcast();
  static void installCaregiverHandler(
    String id,
    Future<void> Function(String) handler,
  ) {
    caregiverActions[id] = handler;
    changes.add(null);
  }

  static void removeCaregiverHandler(
    String id,
    Future<void> Function(String) handler,
  ) {
    if (identical(caregiverActions[id], handler)) {
      caregiverActions.remove(id);
    }
  }

  static final childMeals = <int>{};
  static final caregiverActions = <String, Future<void> Function(String)>{};
  static final caregiverRequests = <String>{};
}
