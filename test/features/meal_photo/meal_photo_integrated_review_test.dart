import 'dart:convert';

import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/common/widgets/confidence_slider.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'products, reference confidence and portions are reviewed in one step with edit-only actions',
    (tester) async {
      final sauce = fixtures.component('sauce', kind: 'proposed_reference')
        ..['name'] = 'Herb sauce'
        ..['search_query'] = 'herb sauce';
      final raw = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      raw['itemized'] = [
        fixtures.component('potatoes', kind: 'proposed_reference'),
        sauce,
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
        languageCode: 'en',
      );
      await controller.divideIntoIngredients(languageCode: 'en');
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
      expect(find.text('Ingredients and portions'), findsOneWidget);
      expect(find.text('Choose another product'), findsNothing);
      expect(find.text('Accept estimated reference'), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Choose another product'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '160');
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm portion and continue'));
      await tester.tap(find.text('Confirm portion and continue'));
      await tester.pumpAndSettle();
      expect(controller.state.items.first.reviewed, isTrue);
      expect(controller.state.step, MealPhotoStep.assignment);
      expect(controller.state.items.last.referenceAccepted, isTrue);
      expect(find.text('AI reference confidence'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Edit'));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit reference values'));
      await tester.tap(find.text('Edit reference values'));
      await tester.pumpAndSettle();
      tester
          .widget<ConfidenceSlider>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(ConfidenceSlider),
            ),
          )
          .onChanged(ConfidenceLevel.high);
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(controller.state.items.last.nutritionConfidence, .75);
      expect(controller.state.items.last.referenceNutritionConfidence, .75);
      await tester.ensureVisible(find.text('Confirm portion and continue'));
      await tester.tap(find.text('Confirm portion and continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(controller.state.step, MealPhotoStep.confirmation);
    },
  );
}
