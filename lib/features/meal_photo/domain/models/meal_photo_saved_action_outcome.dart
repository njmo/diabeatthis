/// The meal is already durable. Errors here concern only its subsequent action.
class MealPhotoSavedActionOutcome {
  const MealPhotoSavedActionOutcome({
    required this.mealId,
    this.error,
    this.stackTrace,
  });
  final int mealId;
  final Object? error;
  final StackTrace? stackTrace;
  bool get actionFailed => error != null;
}
