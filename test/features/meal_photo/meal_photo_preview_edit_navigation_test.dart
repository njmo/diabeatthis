import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  for (final save in [false, true]) {
    testWidgets(
      'preview editing keeps mode choices available after ${save ? "saving" : "cancelling"}',
      (tester) async {
        final candidates = TestPhotoCandidates();
        final controller = MealPhotoController(
          propose: ProposeMealFromPhotoUseCase(
            client: TestPhotoClient(),
            candidates: candidates,
          ),
          saver: TestPhotoSaver(),
        );
        addTearDown(controller.dispose);
        await controller.generate(
          const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
          languageCode: 'en',
        );
        final before = controller.state;
        await tester.pumpWidget(
          harness(
            MealPhotoReviewScreen(
              controller: controller,
              capture: const SizedBox(),
              pickProduct: (_) async => null,
              onSaved: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Edit reference values'));
        await tester.pumpAndSettle();
        expect(controller.state, same(before));
        expect(controller.state.step, MealPhotoStep.mode);
        if (save) {
          await tester.enterText(find.byType(TextFormField).first, '42');
        }
        await tester.tap(find.text(save ? 'Save' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(controller.state.step, MealPhotoStep.mode);
        expect(candidates.queries, isEmpty);
        expect(find.text('Use whole plate proposal'), findsOneWidget);
        expect(find.text('Divide into ingredients'), findsOneWidget);
        if (save) {
          expect(
            controller.state.items.single.referenceNutrition!.netCarbs,
            42,
          );
          controller.acceptWholePlateProposal();
          expect(controller.state.step, MealPhotoStep.amounts);
          expect(
            controller.state.items.single.nutritionForPortion!.netCarbs,
            42,
          );
        } else {
          expect(controller.state, same(before));
          await controller.divideIntoIngredients(languageCode: 'en');
          expect(controller.state.step, MealPhotoStep.assignment);
          expect(candidates.queries, isNotEmpty);
        }
        await tester.pumpAndSettle();
      },
    );
  }
}
