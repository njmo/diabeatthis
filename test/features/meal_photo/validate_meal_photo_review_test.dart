import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/validate_meal_photo_review_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  const validator = ValidateMealPhotoReviewUseCase();
  final proposal = const MealPhotoProposalParser().parse(fixtures.proposal());
  AcceptedMealPhotoReview review(MealPhotoReviewItem item) =>
      AcceptedMealPhotoReview(
        name: 'Lunch',
        mode: MealPhotoMode.reference,
        items: [item],
        proposalResponse: 'original',
        sourceProposal: proposal,
      );
  test('a reference must be explicitly accepted, weighed and reviewed', () {
    final original = MealPhotoReviewItem.fromProposal(proposal.reference);
    expect(() => validator(review(original)), throwsStateError);
    final accepted = original.acceptReference();
    expect(() => validator(review(accepted)), throwsStateError);
    final checked = accepted.adjust(
      grams: 200,
      quantityConfidence: .7,
      nutritionConfidence: .6,
      reviewed: true,
    );
    expect(() => validator(review(checked)), returnsNormally);
    expect(checked.nutritionForPortion!.carbs, 30);
    expect(
      () => validator(
        review(
          checked.adjust(
            grams: 0,
            quantityConfidence: .7,
            nutritionConfidence: .6,
            reviewed: true,
          ),
        ),
      ),
      throwsStateError,
    );
  });
  test(
    'meal review confidence may change without rewriting the catalog candidate',
    () {
      final original = MealPhotoReviewItem.fromProposal(
        proposal.itemized.single,
      ).assign(fixtures.candidate);
      AcceptedMealPhotoReview selected(MealPhotoReviewItem item) =>
          AcceptedMealPhotoReview(
            name: 'Lunch',
            mode: MealPhotoMode.itemized,
            items: [item],
            proposalResponse: proposal.rawResponse,
            sourceProposal: proposal,
          );
      expect(
        () => validator(
          selected(
            original.adjust(
              grams: 150,
              quantityConfidence: .7,
              nutritionConfidence: 0,
              reviewed: true,
            ),
          ),
        ),
        returnsNormally,
      );
      expect(
        () => validator(
          selected(
            original.adjust(
              grams: 150,
              quantityConfidence: .7,
              nutritionConfidence: .9,
              reviewed: true,
            ),
          ),
        ),
        returnsNormally,
      );
      expect(fixtures.candidate.nutritionConfidence, isNull);
      expect(fixtures.candidate.effectiveNutritionConfidence, 0);
    },
  );
  test(
    'zero-energy components and meals below the existing actionable threshold cannot reach confirmation',
    () {
      AcceptedMealPhotoReview selected({
        required double carbs,
        required double fat,
        required double protein,
      }) {
        final json = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
        (json['reference'] as Map<String, dynamic>)['reference_nutrition'] = {
          'carbs': carbs,
          'fiber': 0,
          'fat': fat,
          'protein': protein,
          'carbs_label_mode': 'eu',
        };
        final source = const MealPhotoProposalParser().parse(jsonEncode(json));
        final item = MealPhotoReviewItem.fromProposal(source.reference)
            .acceptReference()
            .adjust(
              grams: 150,
              quantityConfidence: .5,
              nutritionConfidence: .5,
              reviewed: true,
            );
        return AcceptedMealPhotoReview(
          name: 'Lunch',
          mode: MealPhotoMode.reference,
          items: [item],
          proposalResponse: source.rawResponse,
          sourceProposal: source,
        );
      }

      expect(
        () => validator(selected(carbs: 0, fat: 0, protein: 0)),
        throwsStateError,
      );
      expect(
        () => validator(selected(carbs: 0, fat: 0, protein: 2)),
        throwsStateError,
      );
      expect(
        () => validator(selected(carbs: 0, fat: 15, protein: 0)),
        returnsNormally,
      );
      expect(
        () => validator(selected(carbs: 1, fat: 0, protein: 0)),
        returnsNormally,
      );
    },
  );
  test(
    'implausible mass and nonfinite confidence cannot reach persistence',
    () {
      final item = MealPhotoReviewItem.fromProposal(
        proposal.reference,
      ).acceptReference();
      expect(
        () => validator(
          review(
            item.adjust(
              grams: 10,
              quantityConfidence: .5,
              nutritionConfidence: .5,
              reviewed: true,
            ),
          ),
        ),
        throwsStateError,
      );
      expect(
        () => validator(
          review(
            item.adjust(
              grams: 200,
              quantityConfidence: double.nan,
              nutritionConfidence: .5,
              reviewed: true,
            ),
          ),
        ),
        throwsStateError,
      );
    },
  );
}
