import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_clarification_test.dart';
import 'meal_photo_controller_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'whole plate requires one model call and never searches the catalog',
    () async {
      final client = ClarifyingPhotoClient(
        first: fixtures.proposal(),
        second: 'must not be called',
      );
      final candidates = TestPhotoCandidates();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: client,
          candidates: candidates,
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
        languageCode: 'pl',
      );
      expect(controller.state.step, MealPhotoStep.mode);
      expect(candidates.queries, isEmpty);
      controller.acceptWholePlateProposal();
      expect(controller.state.mode, MealPhotoMode.reference);
      expect(candidates.queries, isEmpty);
      expect(client.describes, 1);
      expect(client.resolves, 0);
    },
  );

  test(
    'divide searches USDA first and falls back without another model call',
    () async {
      final row = fixtures.component('potatoes', kind: 'proposed_reference')
        ..['usda_food_name'] = 'Potatoes, boiled, without skin';
      final client = ClarifyingPhotoClient(
        first: fixtures.proposal(item: row),
        second: 'must not be called',
      );
      final candidates = TestPhotoCandidates();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: client,
          candidates: candidates,
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
        languageCode: 'pl',
      );
      expect(candidates.queries, isEmpty);
      await controller.divideIntoIngredients(languageCode: 'pl');
      expect(candidates.queries, [
        'pl:Potatoes, boiled, without skin',
        'pl:potatoes cooked',
      ]);
      expect(controller.state.step, MealPhotoStep.assignment);
      expect(controller.state.items.single.product, isNotNull);
      expect(controller.state.items.single.assigned, isTrue);
      expect(client.resolves, 0);
      expect(
        jsonDecode(
          controller.responses.single.text,
        )['itemized'][0]['usda_food_name'],
        'Potatoes, boiled, without skin',
      );
    },
  );
}
