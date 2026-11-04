import '../models/meal_photo_candidate.dart';
import '../models/meal_photo_input.dart';

abstract interface class MealPhotoRecognitionClient {
  Future<String> describe(MealPhotoInput input);
  Future<String> resolve(
    MealPhotoInput input,
    String descriptionResponse,
    Map<String, List<MealPhotoCandidate>> candidates,
  );
}
