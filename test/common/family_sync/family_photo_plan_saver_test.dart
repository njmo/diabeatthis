import 'package:diabeatthis/common/family_sync/photo/family_photo_plan_saver.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:flutter_test/flutter_test.dart';

const item = MealPhotoItem(
  id: 'apple',
  name: 'Apple',
  searchQuery: 'apple',
  kind: MealPhotoItemKind.matched,
  recognitionConfidence: .9,
  quantityConfidence: .9,
  nutritionConfidence: .8,
);
MealPhotoCandidate candidate({int? localId, String? revision = 'v1'}) =>
    MealPhotoCandidate(
      identity: IngredientIdentity(
        source: localId == null
            ? IngredientSource.firebase
            : IngredientSource.local,
        sourceId: localId == null ? 'apple-catalog' : '$localId',
      ),
      localIngredientId: localId,
      catalogRevision: revision,
      name: 'Apple',
      nutritionPer100g: const MealPhotoNutrition(
        carbs: 15,
        fiber: 3,
        fat: 1,
        protein: 2,
        carbsLabelMode: CarbsLabelMode.nonEu,
      ),
    );
AcceptedMealPhotoReview review(List<MealPhotoReviewItem> items) =>
    AcceptedMealPhotoReview(
      name: 'Lunch',
      mode: MealPhotoMode.itemized,
      items: items,
      proposalResponse: '',
      sourceProposal: MealPhotoProposal(
        name: 'Lunch',
        itemized: [item],
        reference: item,
        rawResponse: '',
      ),
    );
MealPhotoReviewItem selected(MealPhotoCandidate? product) =>
    MealPhotoReviewItem(
      proposal: item,
      product: product,
      weightGrams: 50,
      quantityConfidence: .9,
      nutritionConfidence: .8,
    );
void main() {
  test(
    'photo submits only canonical ingredient references as a family plan',
    () async {
      Map<String, dynamic>? sent;
      final time = DateTime.now().add(const Duration(hours: 1));
      final saver = FamilyPhotoPlanSaver(
        submit: (p) async => sent = p,
        category: () => MealCategory.lunch,
        plannedAt: () => time,
      );
      expect(
        await saver.save(
          review([selected(candidate(localId: 7)), selected(candidate())]),
        ),
        0,
      );
      expect(sent!['plannedAt'], time.millisecondsSinceEpoch);
      expect(sent!['category'], 'lunch');
      expect(sent!['ingredients'], [
        {
          'ingredientId': 7,
          'catalogId': null,
          'catalogRevision': null,
          'grams': 50.0,
        },
        {
          'ingredientId': null,
          'catalogId': 'apple-catalog',
          'catalogRevision': 'v1',
          'grams': 50.0,
        },
      ]);
      expect(sent!.containsKey('nutrition'), isFalse);
      expect(sent!.containsKey('status'), isFalse);
    },
  );
  test(
    'repeated photo ingredients merge without duplicate plan identities',
    () async {
      Map<String, dynamic>? sent;
      final saver = FamilyPhotoPlanSaver(
        submit: (p) async => sent = p,
        category: () => MealCategory.lunch,
        plannedAt: () => DateTime.now().add(const Duration(hours: 1)),
      );
      await saver.save(
        review([
          selected(candidate(localId: 7)),
          selected(candidate(localId: 7)),
        ]),
      );
      expect((sent!['ingredients'] as List).single['grams'], 100);
    },
  );
  test(
    'unmatched references, missing revision and expired date cannot submit',
    () async {
      var calls = 0;
      var date = DateTime.now().add(const Duration(hours: 1));
      final saver = FamilyPhotoPlanSaver(
        submit: (_) async {
          calls++;
        },
        category: () => MealCategory.lunch,
        plannedAt: () => date,
      );
      await expectLater(saver.save(review([selected(null)])), throwsStateError);
      await expectLater(
        saver.save(review([selected(candidate(revision: null))])),
        throwsStateError,
      );
      date = DateTime.now().subtract(const Duration(minutes: 1));
      await expectLater(
        saver.save(review([selected(candidate(localId: 7))])),
        throwsStateError,
      );
      expect(calls, 0);
    },
  );
  test(
    'oversized merged amount and too many items are rejected before sending',
    () async {
      var calls = 0;
      final saver = FamilyPhotoPlanSaver(
        submit: (_) async {
          calls++;
        },
        category: () => MealCategory.lunch,
        plannedAt: () => DateTime.now().add(const Duration(hours: 1)),
      );
      final huge = MealPhotoReviewItem(
        proposal: item,
        product: candidate(localId: 7),
        weightGrams: 6000,
        quantityConfidence: .9,
        nutritionConfidence: .8,
      );
      await expectLater(saver.save(review([huge, huge])), throwsStateError);
      await expectLater(
        saver.save(
          review(List.generate(31, (_) => selected(candidate(localId: 7)))),
        ),
        throwsStateError,
      );
      expect(calls, 0);
    },
  );
}
