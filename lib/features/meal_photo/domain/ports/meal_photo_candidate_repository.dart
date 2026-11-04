import '../models/meal_photo_candidate.dart';

abstract interface class MealPhotoCandidateRepository {
  Future<List<MealPhotoCandidate>> search(
    String query, {
    required String languageCode,
    int limit = 8,
  });
}
