import 'meal_photo_review_exception.dart';

enum MealPhotoTimingMode { eatNow, planned }

class MealPhotoTimingSelection {
  const MealPhotoTimingSelection({
    this.mode = MealPhotoTimingMode.eatNow,
    this.plannedAt,
  });
  final MealPhotoTimingMode mode;
  final DateTime? plannedAt;
  bool isValidAt(DateTime now) =>
      mode == MealPhotoTimingMode.eatNow ||
      (plannedAt != null && plannedAt!.isAfter(now));
  DateTime resolveAt(DateTime now) {
    if (!isValidAt(now)) {
      throw MealPhotoReviewException(MealPhotoReviewFailure.futureTimeRequired);
    }
    return mode == MealPhotoTimingMode.eatNow ? now : plannedAt!;
  }
}
