import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/data/meal_photo_prompt.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_response_schema.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'formal output schema requires complete independent reference and forbids extra alternatives',
    () {
      final prompt = const MealPhotoPrompt().build(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Boiled potatoes',
        ),
      );
      final schemaText = RegExp(
        r'FORMAL_OUTPUT_JSON_SCHEMA:\n(.*?)\nEND_FORMAL_OUTPUT_JSON_SCHEMA',
        dotAll: true,
      ).firstMatch(prompt)!.group(1)!;
      final schema = jsonDecode(schemaText) as Map<String, dynamic>;
      final proposal = (schema['anyOf'] as List).first as Map<String, dynamic>;
      expect(proposal['required'], [
        'schema_version',
        'status',
        'name',
        'itemized',
        'reference',
      ]);
      expect(proposal['additionalProperties'], isFalse);
      expect(schema, MealPhotoResponseSchema.value);
      final properties = proposal['properties'] as Map<String, dynamic>;
      expect(properties.keys.toSet(), {
        'schema_version',
        'status',
        'name',
        'itemized',
        'reference',
      });
      final reference = properties['reference'] as Map<String, dynamic>;
      final componentBranches =
          ((properties['itemized'] as Map<String, dynamic>)['items']
                  as Map<String, dynamic>)['anyOf']
              as List;
      final component = componentBranches.first as Map<String, dynamic>;
      for (final branch in componentBranches) {
        expect((branch as Map)['required'], reference['required']);
        expect(branch['additionalProperties'], isFalse);
      }
      expect(reference['required'], component['required']);
      expect(
        reference['required'],
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
      expect(reference['additionalProperties'], isFalse);
      expect(component['additionalProperties'], isFalse);
      final componentIdSchema = (component['properties'] as Map)['id'] as Map;
      final referenceIds =
          ((reference['properties'] as Map)['id'] as Map)['enum'] as List;
      expect(referenceIds, ['plate_reference']);
      expect(componentIdSchema['type'], 'string');
      expect(componentIdSchema.containsKey('enum'), isFalse);
      final referenceProperties =
          reference['properties'] as Map<String, dynamic>;
      expect(referenceProperties['candidate_key'], {'type': 'null'});
      expect((referenceProperties['kind'] as Map)['enum'], [
        'proposed_reference',
      ]);
      expect(
        (referenceProperties['reference_nutrition'] as Map)['type'],
        'object',
      );
      expect(
        prompt,
        contains(
          'Reference.id MUST differ from EVERY itemized component.id, EVEN FOR A SINGLE-COMPONENT PLATE',
        ),
      );
      expect(prompt, contains('Do not add an alternatives field'));
      expect(
        prompt,
        contains(
          'Reference does NOT mean an ID pointer, alias, shortened object',
        ),
      );
    },
  );
  test(
    'live alias-shaped regression remains rejected; a complete distinct whole-plate object parses',
    () {
      final component = fixtures.component('boiled_potato_1')
        ..['name'] = 'Boiled potato'
        ..['search_query'] = 'boiled potato';
      final alias = <String, dynamic>{
        'id': 'boiled_potato_1',
        'kind': 'proposed_reference',
        'estimated_weight_grams': 180,
        'recognition_confidence': .9,
        'quantity_confidence': .3,
        'nutrition_confidence': .3,
        'reason': 'User description and image analysis',
        'reference_nutrition': {
          'carbs': 31.5,
          'fiber': 3.6,
          'fat': .18,
          'protein': 3.6,
          'carbs_label_mode': 'eu',
        },
      };
      final invalid = {
        'schema_version': 1,
        'status': 'proposal',
        'name': 'Boiled potatoes',
        'itemized': [component],
        'reference': alias,
        'alternatives': {
          'weights': [120, 250],
        },
      };
      const parser = MealPhotoProposalParser();
      expect(() => parser.parse(jsonEncode(invalid)), throwsFormatException);
      final corrected = {
        'schema_version': 1,
        'status': 'proposal',
        'name': 'Boiled potatoes',
        'itemized': [
          {...component, 'id': 'component_1'},
        ],
        'reference': {
          ...alias,
          'id': 'plate_reference',
          'name': 'Whole plate of boiled potatoes',
          'search_query': 'boiled potato',
          'candidate_key': null,
        },
      };
      final parsed = parser.parse(jsonEncode(corrected));
      expect(parsed.reference.id, isNot(parsed.itemized.single.id));
      expect(parsed.reference.name, 'Whole plate of boiled potatoes');
      expect(parsed.reference.searchQuery, 'boiled potato');
      expect(parsed.reference.referenceNutrition!.carbs, 31.5);
      expect(parsed.reference.estimatedWeightGrams, 180);
    },
  );
}
