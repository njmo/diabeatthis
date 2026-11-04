import 'dart:convert';

import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> component(
  String id, {
  String kind = 'needs_assignment',
  String? key,
}) => {
  'id': id,
  'name': 'Cooked potatoes',
  'search_query': 'potatoes cooked',
  'kind': kind,
  'candidate_key': key,
  'estimated_weight_grams': 150,
  'recognition_confidence': .8,
  'quantity_confidence': .8,
  'nutrition_confidence': .3,
  'reference_nutrition': kind == 'proposed_reference'
      ? {
          'carbs': 30,
          'fiber': 3,
          'fat': 2,
          'protein': 4,
          'carbs_label_mode': 'eu',
        }
      : null,
};
String proposal({Map<String, dynamic>? item}) => jsonEncode({
  'schema_version': 1,
  'name': 'Lunch',
  'itemized': [item ?? component('potatoes')],
  'reference': component('plate', kind: 'proposed_reference'),
});
const candidate = MealPhotoCandidate(
  identity: IngredientIdentity(source: IngredientSource.local, sourceId: '7'),
  name: 'Potatoes',
  nutritionPer100g: MealPhotoNutrition(
    carbs: 20,
    fiber: 2,
    fat: 0,
    protein: 2,
    carbsLabelMode: CarbsLabelMode.eu,
  ),
);
void main() {
  const parser = MealPhotoProposalParser();
  test(
    'photo quantities remain low confidence; reference describes the whole portion',
    () {
      final result = parser.parse(proposal());
      expect(result.itemized.single.quantityConfidence, .5);
      expect(result.reference.referenceNutrition!.carbs, 30);
      expect(result.reference.estimatedWeightGrams, 150);
      expect(
        MealPhotoReviewItem.fromProposal(result.reference).assigned,
        isFalse,
      );
    },
  );
  test('matches resolve exclusively within supplied component candidates', () {
    expect(
      () => parser.parse(
        proposal(
          item: component('potatoes', kind: 'matched', key: 'local:7'),
        ),
      ),
      throwsFormatException,
    );
    final result = parser.parse(
      proposal(
        item: component('potatoes', kind: 'matched', key: 'local:7'),
      ),
      candidates: {
        'potatoes': [candidate],
      },
    );
    final item = MealPhotoReviewItem.fromProposal(result.itemized.single);
    expect(item.nutritionForPortion!.carbs, 30);
    expect(item.nutritionForPortion!.netCarbs, 30);
    expect(
      () => parser.parse(
        proposal(
          item: component('wrong', kind: 'matched', key: 'local:7'),
        ),
        candidates: {
          'potatoes': [candidate],
        },
      ),
      throwsFormatException,
    );
  });
  test(
    'replacing a product preserves physical grams and invalidates review',
    () {
      final original =
          MealPhotoReviewItem.fromProposal(
            parser.parse(proposal()).itemized.single,
          ).adjust(
            grams: 230,
            quantityConfidence: .9,
            nutritionConfidence: .7,
            reviewed: true,
          );
      final changed = original.assign(candidate);
      expect(changed.weightGrams, 230);
      expect(changed.nutritionForPortion!.carbs, 46);
      expect(changed.reviewed, isFalse);
    },
  );
  test('US fiber is subtracted once and EU fiber is not subtracted', () {
    const us = MealPhotoNutrition(
      carbs: 24,
      fiber: 4,
      fat: 1,
      protein: 2,
      carbsLabelMode: CarbsLabelMode.nonEu,
    );
    expect(us.scaled(1.5).netCarbs, 30);
    expect(candidate.nutritionPer100g.scaled(1.5).netCarbs, 30);
  });
  test('negative weights and component identity drift are rejected', () {
    expect(
      () => parser.parse(
        proposal(item: component('potatoes')..['estimated_weight_grams'] = -1),
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(proposal(), expectedIds: {'rice'}),
      throwsFormatException,
    );
  });
}
