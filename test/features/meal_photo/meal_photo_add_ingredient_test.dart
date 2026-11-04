import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart'
    show TestPhotoCandidates, TestPhotoClient, TestPhotoSaver;
import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'manual additions preserve AI response and require a confirmed portion',
    () async {
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: TestPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(mealPhotoPath: 'meal.jpg'),
        languageCode: 'pl',
      );
      controller.chooseMode(MealPhotoMode.itemized);
      final original = controller.state.proposal!;
      controller.addIngredient(product: fixtures.candidate);
      final addedProduct = controller.state.items.first;
      expect(addedProduct.displayName, fixtures.candidate.name);
      expect(addedProduct.assigned, isTrue);
      expect(addedProduct.validWeight, isFalse);
      expect(addedProduct.reviewed, isFalse);
      controller.addIngredient(
        name: '  Extra sauce  ',
        nutrition: original.reference.referenceNutrition,
        confidence: .75,
      );
      final reference = controller.state.items.first;
      expect(reference.displayName, 'Extra sauce');
      expect(reference.referenceAccepted, isTrue);
      expect(reference.nutritionConfidence, .75);
      expect(reference.validWeight, isFalse);
      expect(reference.proposal.id, isNot(addedProduct.proposal.id));
      expect(
        controller.state.proposal!.itemized.length,
        original.itemized.length + 2,
      );
      expect(controller.state.proposal!.rawResponse, original.rawResponse);
    },
  );
}
