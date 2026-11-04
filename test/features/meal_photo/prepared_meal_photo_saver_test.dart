import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_draft_settings.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_draft_writer.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_reference_draft_factory.dart';
import 'package:diabeatthis/features/meal_photo/data/prepared_meal_photo_saver.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

class ReferenceTestResolver implements MealPhotoDraftIngredientResolver {
  final items = <MealPhotoReviewItem>[];
  @override
  Future<IngredientDraft> resolve(MealPhotoReviewItem item) async {
    items.add(item);
    return const MealPhotoReferenceDraftFactory()(item);
  }
}

class RecordingPhotoDraftWriter implements MealPhotoDraftWriter {
  MealDraft? draft;
  @override
  Future<int> write(MealDraft value) async {
    draft = value;
    return 43;
  }
}

void main() {
  test(
    'confirmed physical grams roundtrip exact whole-plate macros through existing draft boundary',
    () async {
      final proposal = const MealPhotoProposalParser().parse(
        fixtures.proposal(),
      );
      final item = MealPhotoReviewItem.fromProposal(proposal.reference)
          .acceptReference()
          .adjust(
            grams: 250,
            quantityConfidence: .7,
            nutritionConfidence: .6,
            reviewed: true,
          );
      final review = AcceptedMealPhotoReview(
        name: 'Lunch',
        mode: MealPhotoMode.reference,
        items: [item],
        proposalResponse: proposal.rawResponse,
        sourceProposal: proposal,
      );
      final resolver = ReferenceTestResolver();
      final writer = RecordingPhotoDraftWriter();
      var atomicCalls = 0;
      final date = DateTime(2026, 11, 3, 12);
      final saver = PreparedMealPhotoSaver(
        ingredients: resolver,
        writer: writer,
        settings: () => MealPhotoDraftSettings(
          category: MealCategory.lunch,
          plannedAt: date,
        ),
        runAtomic: (action) async {
          atomicCalls++;
          return action();
        },
      );
      expect(await saver.save(review), 43);
      expect(atomicCalls, 1);
      final draft = writer.draft!;
      expect(draft.category, MealCategory.lunch);
      expect(draft.plannedAt, date);
      expect(draft.status, 'planned');
      final entry = draft.mealIngredients.single;
      expect(entry.amount, 250);
      expect(entry.recordedGramsPerAmount, 1);
      expect(entry.quantityConfidence, .7);
      expect(entry.ingredient.isReference, isFalse);
      expect(entry.ingredient.carbsPer100g, 12);
      expect(entry.ingredient.fiberPer100g, closeTo(1.2, 1e-10));
      expect(entry.ingredient.fatPer100g, .8);
      expect(entry.ingredient.proteinPer100g, 1.6);
      expect(entry.ingredient.carbsPer100g * entry.amount / 100, 30);
      expect(
        entry.ingredient.fiberPer100g * entry.amount / 100,
        closeTo(3, 1e-10),
      );
    },
  );
  test(
    'unassigned or unchecked proposal cannot trigger transaction or database writer',
    () async {
      final proposal = const MealPhotoProposalParser().parse(
        fixtures.proposal(),
      );
      var writes = 0;
      final saver = PreparedMealPhotoSaver(
        ingredients: ReferenceTestResolver(),
        writer: RecordingPhotoDraftWriter(),
        settings: () => MealPhotoDraftSettings(
          category: MealCategory.lunch,
          plannedAt: DateTime(2026),
        ),
        runAtomic: (action) async {
          writes++;
          return action();
        },
      );
      final review = AcceptedMealPhotoReview(
        name: 'Lunch',
        mode: MealPhotoMode.reference,
        items: [MealPhotoReviewItem.fromProposal(proposal.reference)],
        proposalResponse: proposal.rawResponse,
        sourceProposal: proposal,
      );
      await expectLater(saver.save(review), throwsStateError);
      expect(writes, 0);
    },
  );
}
