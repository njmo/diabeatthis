import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart'
    show TestPhotoCandidates, TestPhotoClient, TestPhotoSaver;

void main() {
  test(
    'edited meal name survives review and reaches save without changing AI source',
    () async {
      final saver = TestPhotoSaver();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: TestPhotoCandidates(),
        ),
        saver: saver,
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(mealPhotoPath: 'meal.jpg'),
        languageCode: 'pl',
      );
      final source = controller.state.proposal!;
      controller.renameMeal('  Lunch at home  ');
      expect(controller.mealName, 'Lunch at home');
      expect(() => controller.renameMeal('   '), throwsArgumentError);
      controller.chooseMode(MealPhotoMode.reference);
      controller.acceptReference('plate');
      controller.next();
      controller.setAmount(
        'plate',
        grams: 150,
        quantityConfidence: .5,
        nutritionConfidence: .75,
        reviewed: true,
      );
      controller.next();
      final saving = controller.save(confirmed: true);
      expect(saver.accepted!.name, 'Lunch at home');
      expect(saver.accepted!.sourceProposal, same(source));
      expect(source.name, isNot('Lunch at home'));
      saver.result.complete(7);
      await saving;
    },
  );
}
