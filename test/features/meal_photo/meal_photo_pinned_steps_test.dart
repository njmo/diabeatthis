import 'package:diabeatthis/common/widgets/form_step_header.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart'
    show TestPhotoCandidates, TestPhotoClient, TestPhotoSaver;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets('review steps remain fixed while the ingredient card scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
      languageCode: 'en',
    );
    controller.chooseMode(MealPhotoMode.itemized);
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
    await tester.pumpAndSettle();
    final header = find.byType(FormStepHeader);
    final originalTop = tester.getTopLeft(header).dy;
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(header).dy, originalTop);
    expect(header.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
