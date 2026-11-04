import '../../../../common/ingredient_catalog/ingredient_match_score.dart';
import '../models/meal_photo_candidate.dart';
import '../models/meal_photo_item.dart';
import '../ports/meal_photo_candidate_repository.dart';

/// Suggests the closest compatible catalog name for explicit human review.
class FindMealPhotoProductUseCase {
  const FindMealPhotoProductUseCase(this.candidates);
  final MealPhotoCandidateRepository candidates;

  Future<MealPhotoCandidate?> call(
    MealPhotoItem item, {
    required String languageCode,
  }) async {
    final queries = {
      if (item.usdaFoodName != null) item.usdaFoodName!,
      item.searchQuery,
      item.name,
    };
    MealPhotoCandidate? best;
    var bestScore = .49;
    for (final query in queries) {
      if (query == item.name && best != null) break;
      final results = await candidates.search(
        query,
        languageCode: languageCode,
        limit: 1,
      );
      for (final candidate in results) {
        final score = ingredientNameMatchScore(
          query,
          candidate.name,
          candidate.catalogIngredient?.englishName,
        );
        if (score > bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
      if (bestScore == 1) break;
    }
    return best;
  }
}
