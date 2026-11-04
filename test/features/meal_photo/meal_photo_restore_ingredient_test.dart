import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

void main() {
  test(
    'undo restores the same component, assignment and quantity without leaving exclusions',
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
        const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
        languageCode: 'en',
      );
      controller.chooseMode(MealPhotoMode.itemized);
      final original = controller.state.items.single;
      controller.removeIngredient(original.proposal.id);
      expect(controller.state.items, isEmpty);
      controller.restoreIngredient(original, 0);
      expect(controller.state.items.single, same(original));
      expect(controller.excludedItemIds, isEmpty);
    },
  );
}
