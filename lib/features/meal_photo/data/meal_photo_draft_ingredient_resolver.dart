import '../../ingredients/data/drafts/ingredient_draft.dart';
import '../domain/models/meal_photo_review_item.dart';

abstract interface class MealPhotoDraftIngredientResolver {
  Future<IngredientDraft> resolve(MealPhotoReviewItem item);
}
