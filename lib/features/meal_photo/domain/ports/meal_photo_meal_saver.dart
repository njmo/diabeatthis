import '../models/accepted_meal_photo_review.dart';

abstract interface class MealPhotoMealSaver {
  Future<int> save(AcceptedMealPhotoReview review);
}
