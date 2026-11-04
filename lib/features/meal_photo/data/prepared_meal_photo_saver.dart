import '../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../meals/data/drafts/meal_draft.dart';
import '../../portions/data/drafts/portion_draft.dart';
import '../domain/models/accepted_meal_photo_review.dart';
import '../domain/ports/meal_photo_meal_saver.dart';
import '../domain/use_cases/validate_meal_photo_review_use_case.dart';
import 'meal_photo_draft_ingredient_resolver.dart';
import 'meal_photo_draft_settings.dart';
import 'meal_photo_draft_writer.dart';

class PreparedMealPhotoSaver implements MealPhotoMealSaver {
  const PreparedMealPhotoSaver({
    required this.ingredients,
    required this.writer,
    required this.settings,
    required this.runAtomic,
    this.validate = const ValidateMealPhotoReviewUseCase(),
  });
  final MealPhotoDraftIngredientResolver ingredients;
  final MealPhotoDraftWriter writer;
  final MealPhotoDraftSettings Function() settings;
  final Future<int> Function(Future<int> Function()) runAtomic;
  final ValidateMealPhotoReviewUseCase validate;
  @override
  Future<int> save(AcceptedMealPhotoReview review) async {
    validate(review);
    final selectedSettings = settings();
    return runAtomic(() async {
      final items = <MealIngredientsDraft>[];
      for (final item in review.items) {
        final ingredient = await ingredients.resolve(item);
        items.add(
          MealIngredientsDraft(
            ingredient: ingredient,
            ingredientPortion: const IngredientPortionDraft(
              portion: PortionSelection.empty(),
              amount: 1,
            ),
            amount: item.weightGrams!,
            recordedGramsPerAmount: 1,
            quantityConfidence: item.quantityConfidence,
            nutritionConfidenceOverride: item.nutritionConfidence,
            entryType: 'planned',
            consumedAmount: null,
            consumedConfidence: null,
          ),
        );
      }
      return writer.write(
        MealDraft(
          name: review.name,
          category: selectedSettings.category,
          plannedAt: selectedSettings.plannedAt,
          status: 'planned',
          mealIngredients: items,
        ),
      );
    });
  }
}
