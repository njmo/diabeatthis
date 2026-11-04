import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_reference_preview_data.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

void main() {
  test(
    'whole-plate edits survive reopening the entry and are used by preview and amount review',
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
        languageCode: 'pl',
      );
      controller.chooseMode(MealPhotoMode.reference);
      const facts = MealPhotoNutrition(
        carbs: 25,
        fiber: 2,
        fat: 3,
        protein: 4,
        carbsLabelMode: CarbsLabelMode.eu,
      );
      controller.setManualReference('plate', facts);
      controller.back();
      final preview = MealPhotoReferencePreviewData.fromProposal(
        controller.state.proposal!,
        referenceNutrition: controller.state.items.single.referenceNutrition,
      );
      expect(preview.netCarbsGrams, 25);
      controller.chooseMode(MealPhotoMode.reference);
      expect(controller.state.items.single.referenceNutrition, same(facts));
      controller.back();
      controller.acceptWholePlateProposal();
      expect(controller.state.items.single.nutritionForPortion, same(facts));
    },
  );
}
