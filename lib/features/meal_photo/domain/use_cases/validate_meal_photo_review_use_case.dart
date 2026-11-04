import '../../../../common/nutrition/stable_macro_ceil.dart';
import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../models/accepted_meal_photo_review.dart';
import '../models/meal_photo_item.dart';
import '../models/meal_photo_proposal.dart';
import '../models/meal_photo_review_exception.dart';

class ValidateMealPhotoReviewUseCase {
  const ValidateMealPhotoReviewUseCase();
  void call(AcceptedMealPhotoReview review) {
    if (review.name.trim().isEmpty ||
        review.items.isEmpty ||
        (review.mode == MealPhotoMode.reference && review.items.length != 1)) {
      throw StateError('Invalid meal proposal selection');
    }
    final sources = review.sourceProposal.itemsFor(review.mode);
    if ((review.mode == MealPhotoMode.reference &&
            review.excludedItemIds.isNotEmpty) ||
        review.excludedItemIds.any(
          (id) => !sources.any((source) => source.id == id),
        )) {
      throw StateError('Invalid excluded meal components');
    }
    final expected = sources
        .where((source) => !review.excludedItemIds.contains(source.id))
        .toList();
    if (review.items.length != expected.length ||
        review.items.any(
          (item) => !expected.any((source) => identical(source, item.proposal)),
        )) {
      throw StateError(
        'Review components do not belong to the selected proposal',
      );
    }
    final ids = <String>{};
    var netCarbsTotal = 0.0;
    var fatTotal = 0.0;
    var proteinTotal = 0.0;
    for (final item in review.items) {
      if (!ids.add(item.proposal.id) ||
          !item.assigned ||
          !item.validWeight ||
          !item.reviewed) {
        throw StateError(
          'Every component requires assignment, physical weight and explicit review',
        );
      }
      for (final confidence in [
        item.quantityConfidence,
        item.nutritionConfidence,
      ]) {
        if (!confidence.isFinite || confidence < 0 || confidence > 1) {
          throw StateError('Invalid reviewed confidence');
        }
      }
      if ((review.mode == MealPhotoMode.reference) !=
              (item.proposal.referenceScope ==
                  MealPhotoReferenceScope.wholeMeal) ||
          (review.mode == MealPhotoMode.reference &&
              (!item.referenceAccepted || item.product != null))) {
        throw StateError(
          'Whole-plate reference must preserve its complete nutrition',
        );
      }
      final nutrition = item.nutritionForPortion;
      if (nutrition == null) throw StateError('Missing nutrition');
      nutrition.validate();
      if (nutrition.carbs == 0 &&
          nutrition.fat == 0 &&
          nutrition.protein == 0) {
        throw MealPhotoReviewException(
          MealPhotoReviewFailure.energyMacrosRequired,
        );
      }
      if (nutrition.carbsLabelMode == CarbsLabelMode.nonEu &&
          nutrition.carbs > 0 &&
          nutrition.carbs < nutrition.fiber) {
        throw MealPhotoReviewException(
          MealPhotoReviewFailure.invalidCarbohydrateFacts,
        );
      }
      netCarbsTotal += nutrition.netCarbs;
      fatTotal += nutrition.fat;
      proteinTotal += nutrition.protein;
      final mass =
          nutrition.carbs +
          nutrition.fat +
          nutrition.protein +
          (nutrition.carbsLabelMode == CarbsLabelMode.eu ? nutrition.fiber : 0);
      if ([
            nutrition.carbs,
            nutrition.fiber,
            nutrition.fat,
            nutrition.protein,
          ].any((value) => value > item.weightGrams!) ||
          mass > item.weightGrams! * 1.01) {
        throw MealPhotoReviewException(MealPhotoReviewFailure.invalidMass);
      }
    }
    final extended = const WbtExtendedCarbsCalculator().calculateFromMacros(
      fatGrams: fatTotal,
      proteinGrams: proteinTotal,
    );
    if (netCarbsTotal.ceilMacro() <= 0 && extended.grams <= 0) {
      throw MealPhotoReviewException(
        MealPhotoReviewFailure.actionableCarbsRequired,
      );
    }
  }
}
