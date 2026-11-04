import 'dart:convert';

import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_prompt.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_response_schema.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'provider item branches require one source with mutually exclusive key and nutrition fields',
    () {
      final proposal =
          (MealPhotoResponseSchema.value['anyOf'] as List).first as Map;
      final items =
          ((proposal['properties'] as Map)['itemized'] as Map)['items'] as Map;
      final branches = items['anyOf'] as List;
      expect(branches.length, 3);
      final byKind = <String, Map>{
        for (final branch in branches)
          (((branch as Map)['properties'] as Map)['kind'] as Map)['enum'].single
                  as String:
              branch,
      };
      expect(byKind.keys.toSet(), {
        'matched',
        'needs_assignment',
        'proposed_reference',
      });
      for (final branch in byKind.values) {
        expect(
          branch['required'],
          containsAll([
            'id',
            'name',
            'search_query',
            'kind',
            'candidate_key',
            'estimated_weight_grams',
            'recognition_confidence',
            'quantity_confidence',
            'nutrition_confidence',
            'reason',
            'reference_nutrition',
          ]),
        );
        expect(branch['additionalProperties'], isFalse);
      }
      Map properties(String kind) => byKind[kind]!['properties'] as Map;
      expect(properties('matched')['candidate_key'], {'type': 'string'});
      expect(properties('matched')['reference_nutrition'], {'type': 'null'});
      expect(properties('needs_assignment')['candidate_key'], {'type': 'null'});
      expect(properties('needs_assignment')['reference_nutrition'], {
        'type': 'null',
      });
      expect(properties('proposed_reference')['candidate_key'], {
        'type': 'null',
      });
      expect(
        (properties('proposed_reference')['reference_nutrition']
            as Map)['type'],
        'object',
      );
      final reference = (proposal['properties'] as Map)['reference'] as Map;
      expect(((reference['properties'] as Map)['kind'] as Map)['enum'], [
        'proposed_reference',
      ]);
    },
  );
  test(
    'actual matched-plus-estimate regression is rejected instead of silently mixing nutrition sources',
    () {
      const candidate = MealPhotoCandidate(
        identity: IngredientIdentity(
          source: IngredientSource.firebase,
          sourceId: 'usda_170440',
        ),
        name: 'Potatoes, boiled, cooked without skin',
        nutritionPer100g: MealPhotoNutrition(
          carbs: 18.21,
          fiber: 1.8,
          fat: .09,
          protein: 2.05,
          carbsLabelMode: CarbsLabelMode.nonEu,
        ),
      );
      final payload = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      final matched =
          fixtures.component('component_1', kind: 'matched', key: candidate.key)
            ..['reference_nutrition'] = {
              'carbs': 27.315,
              'fiber': 2.7,
              'fat': .135,
              'protein': 3.075,
              'carbs_label_mode': 'non_eu',
            };
      payload['itemized'] = [matched];
      (payload['reference'] as Map<String, dynamic>)['id'] = 'plate_reference';
      const parser = MealPhotoProposalParser();
      expect(
        () => parser.parse(
          jsonEncode(payload),
          candidates: {
            'component_1': [candidate],
          },
        ),
        throwsFormatException,
      );
      matched['reference_nutrition'] = null;
      final accepted = parser.parse(
        jsonEncode(payload),
        candidates: {
          'component_1': [candidate],
        },
      );
      expect(accepted.itemized.single.candidate, same(candidate));
      expect(accepted.itemized.single.referenceNutrition, isNull);
      final portion = MealPhotoReviewItem.fromProposal(
        accepted.itemized.single,
      ).nutritionForPortion!;
      expect(portion.carbs, closeTo(27.315, 1e-10));
      expect(portion.fiber, closeTo(2.7, 1e-10));
      expect(portion.netCarbs, closeTo(24.615, 1e-10));
    },
  );
  test(
    'resolution prompt explicitly discards the previous estimate when matching a catalog product',
    () {
      final prompt = const MealPhotoPrompt().build(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Boiled potato',
        ),
        descriptionResponse: 'previous estimate',
      );
      expect(prompt, contains('reference_nutrition MUST be null'));
      expect(
        prompt,
        contains(
          'explicitly discard any reference_nutrition carried by that component from the first-stage estimate',
        ),
      );
      expect(
        prompt,
        contains(
          'needs_assignment MUST have candidate_key null and reference_nutrition null',
        ),
      );
    },
  );
}
