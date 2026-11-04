import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'explicit removal excludes only that ingredient from validated review while preserving source',
    () async {
      final raw = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      raw['itemized'] = [
        fixtures.component('keep', kind: 'proposed_reference'),
        fixtures.component('remove', kind: 'proposed_reference'),
      ];
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient()..resolved = jsonEncode(raw),
          candidates: TestPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
        languageCode: 'pl',
      );
      controller.chooseMode(MealPhotoMode.itemized);
      controller.removeIngredient('remove');
      expect(controller.state.items.single.proposal.id, 'keep');
      controller.acceptReference('keep');
      controller.next();
      controller.setAmount(
        'keep',
        grams: 150,
        quantityConfidence: .5,
        nutritionConfidence: .5,
        reviewed: true,
      );
      controller.next();
      expect(controller.state.step, MealPhotoStep.confirmation);
      expect(controller.review().excludedItemIds, {'remove'});
      expect(controller.review().sourceProposal.itemized, hasLength(2));
      expect(controller.review().items, hasLength(1));
    },
  );
}
