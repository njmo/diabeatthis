import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_clarification_test.dart';
import 'meal_photo_controller_test.dart';

void main() {
  test('chicken with beets and potatoes proposal advances to products', () async {
    Map<String, dynamic> item(
      String id,
      String name,
      String query,
      int grams,
      List<double> macros,
      double nutritionConfidence,
    ) => {
      'id': id,
      'name': name,
      'search_query': query,
      'kind': 'proposed_reference',
      'candidate_key': null,
      'estimated_weight_grams': grams,
      'recognition_confidence': 0.9,
      'quantity_confidence': 0.5,
      'nutrition_confidence': nutritionConfidence,
      'reason': 'Visual identification and user description',
      'reference_nutrition': {
        'carbs': macros[0],
        'fiber': macros[1],
        'fat': macros[2],
        'protein': macros[3],
        'carbs_label_mode': 'eu',
      },
    };
    const name = 'Kurczak w sosie ziołowym z buraczkami i ziemniakami';
    final raw = jsonEncode({
      'schema_version': 1,
      'status': 'proposal',
      'name': name,
      'itemized': [
        item(
          'component_1',
          'Kurczak w sosie ziołowym',
          'chicken in herb sauce',
          250,
          [4, 1, 19.5, 49.5],
          0.6,
        ),
        item('component_2', 'Buraczki', 'cooked beets', 120, [
          8.6,
          3.4,
          0.2,
          1.9,
        ], 0.6),
        item('component_3', 'Ziemniaki', 'boiled potatoes', 350, [
          64.1,
          6.3,
          0.4,
          8.1,
        ], 0.8),
      ],
      'reference':
          item(
              'plate_reference',
              name,
              'chicken in herb sauce with beets and potatoes meal',
              720,
              [76.7, 10.7, 20.1, 59.5],
              0.7,
            )
            ..['reason'] =
                'Composite meal based on visual identification and user description',
    });
    final controller = MealPhotoController(
      propose: ProposeMealFromPhotoUseCase(
        client: ClarifyingPhotoClient(first: raw, second: raw),
        candidates: TestPhotoCandidates(),
      ),
      saver: TestPhotoSaver(),
    );
    addTearDown(controller.dispose);

    await controller.generate(
      const MealPhotoInput(mealPhotoPath: 'plate.jpg', description: name),
      languageCode: 'pl',
    );

    expect(controller.state.error, isNull);
    expect(controller.state.clarification, isNull);
    expect(controller.state.step, MealPhotoStep.mode);
    expect(controller.state.proposal!.itemized, hasLength(3));
    expect(controller.responses, hasLength(1));
  });
}
