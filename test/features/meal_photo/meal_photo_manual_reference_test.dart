import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_reference_draft_factory.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'unassigned sauce supports manually entered reference without changing the model proposal',
    () {
      final source = const MealPhotoProposalParser()
          .parse(fixtures.proposal())
          .itemized
          .single;
      final original = MealPhotoReviewItem.fromProposal(source);
      const nutrition = MealPhotoNutrition(
        carbs: 5,
        fiber: 1,
        fat: 8,
        protein: 2,
        carbsLabelMode: CarbsLabelMode.eu,
      );
      final manual = original
          .withManualReference(nutrition)
          .adjust(
            grams: 70,
            quantityConfidence: .4,
            nutritionConfidence: .5,
            reviewed: true,
          );
      expect(manual.proposal, same(source));
      expect(source.referenceNutrition, isNull);
      expect(manual.assigned, isTrue);
      expect(manual.nutritionForPortion, same(nutrition));
      final draft = const MealPhotoReferenceDraftFactory()(manual);
      expect(draft.carbsPer100g, closeTo(5 / 70 * 100, .00001));
      expect(draft.fatPer100g, closeTo(8 / 70 * 100, .00001));
      expect(
        manual.assign(fixtures.candidate).manualReferenceNutrition,
        same(nutrition),
      );
    },
  );
}
