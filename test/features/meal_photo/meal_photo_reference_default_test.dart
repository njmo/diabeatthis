import 'dart:convert';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_reference_draft_factory.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_reference_preview_data.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_assignment_tile.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_reference_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'whole plate preview uses canonical net carbs and fat/protein eCarbs, preserving source facts',
    () {
      final payload = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      payload['name'] = 'LLM meal name';
      (payload['reference'] as Map<String, dynamic>)['reference_nutrition'] = {
        'carbs': 30.000000000000004,
        'fiber': 3,
        'fat': 12,
        'protein': 10,
        'carbs_label_mode': 'eu',
      };
      final proposal = const MealPhotoProposalParser().parse(
        jsonEncode(payload),
      );
      final data = MealPhotoReferencePreviewData.fromProposal(proposal);
      expect(data.name, 'LLM meal name');
      expect(data.netCarbsGrams, 30);
      expect(data.extendedCarbsGrams, 15);
      expect(proposal.reference.referenceNutrition!.carbs, 30.000000000000004);
      expect(proposal.reference.referenceNutrition!.fiber, 3);
    },
  );
  test(
    'US preview subtracts fiber once and keeps the existing WBT threshold',
    () {
      final payload = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      (payload['reference'] as Map<String, dynamic>)['reference_nutrition'] = {
        'carbs': 35,
        'fiber': 5,
        'fat': 0,
        'protein': 25,
        'carbs_label_mode': 'non_eu',
      };
      final data = MealPhotoReferencePreviewData.fromProposal(
        const MealPhotoProposalParser().parse(jsonEncode(payload)),
      );
      expect(data.netCarbsGrams, 30);
      expect(data.extendedCarbsGrams, 0);
    },
  );
  test(
    'primary reference path still requires physical grams, confidence review and final confirmation',
    () async {
      final payload = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      (payload['reference'] as Map<String, dynamic>)['estimated_weight_grams'] =
          null;
      final saver = TestPhotoSaver();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient()..resolved = jsonEncode(payload),
          candidates: TestPhotoCandidates(),
        ),
        saver: saver,
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes',
        ),
        languageCode: 'en',
      );
      expect(controller.state.mode, MealPhotoMode.reference);
      expect(controller.state.items, isEmpty);
      controller.acceptWholePlateProposal();
      expect(controller.state.step, MealPhotoStep.amounts);
      expect(controller.state.items.single.referenceAccepted, isTrue);
      expect(controller.state.allReviewed, isFalse);
      expect(controller.next, throwsStateError);
      expect(() => controller.save(confirmed: true), throwsStateError);
      expect(saver.calls, 0);
      controller.setAmount(
        'plate',
        grams: 200,
        quantityConfidence: .7,
        nutritionConfidence: .6,
        reviewed: false,
      );
      expect(controller.next, throwsStateError);
      controller.setAmount(
        'plate',
        grams: 275,
        quantityConfidence: .7,
        nutritionConfidence: .6,
        reviewed: true,
      );
      controller.acceptWholePlateProposal();
      expect(controller.state.items.single.weightGrams, 275);
      expect(controller.state.items.single.reviewed, isTrue);
      final draft = const MealPhotoReferenceDraftFactory()(
        controller.state.items.single,
      );
      expect(draft.isReference, isFalse);
      expect(draft.carbsPer100g, 30 * (100 / 275));
      expect(draft.fiberPer100g, 3 * (100 / 275));
      controller.next();
      expect(saver.calls, 0);
      expect(() => controller.save(confirmed: false), throwsStateError);
      final pending = controller.save(confirmed: true);
      expect(saver.calls, 1);
      expect(saver.accepted!.items.single.weightGrams, 275);
      expect(saver.accepted!.items.single.nutritionForPortion!.carbs, 30);
      saver.result.complete(42);
      expect(await pending, 42);
    },
  );
  test(
    'reference back returns to preview and forward preserves accepted grams and confidence',
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
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes',
        ),
        languageCode: 'en',
      );
      controller.acceptWholePlateProposal();
      controller.setAmount(
        'plate',
        grams: 275,
        quantityConfidence: .8,
        nutritionConfidence: .9,
        reviewed: true,
      );
      final reviewed = controller.state.items.single;
      controller.back();
      expect(controller.state.step, MealPhotoStep.mode);
      expect(controller.state.items.single, same(reviewed));
      controller.acceptWholePlateProposal();
      expect(controller.state.step, MealPhotoStep.amounts);
      expect(controller.state.items.single, same(reviewed));
      expect(controller.state.items.single.weightGrams, 275);
      expect(controller.state.items.single.quantityConfidence, .8);
      expect(controller.state.items.single.nutritionConfidence, .9);
      expect(controller.state.items.single.reviewed, isTrue);
      expect(controller.state.items.single.referenceAccepted, isTrue);
      controller.next();
      expect(controller.state.step, MealPhotoStep.confirmation);
      expect(() => controller.save(confirmed: false), throwsStateError);
      expect(saver.calls, 0);
    },
  );
  test(
    'a fresh proposal from Context cannot reuse an earlier accepted reference even when IDs match',
    () async {
      final client = TestPhotoClient();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: client,
          candidates: TestPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes',
        ),
        languageCode: 'en',
      );
      controller.acceptWholePlateProposal();
      controller.setAmount(
        'plate',
        grams: 275,
        quantityConfidence: .8,
        nutritionConfidence: .9,
        reviewed: true,
      );
      final old = controller.state.items.single;
      controller.back();
      controller.back();
      expect(controller.state.step, MealPhotoStep.capture);
      final payload = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      payload['name'] = 'Fresh plate';
      (payload['reference'] as Map<String, dynamic>)['estimated_weight_grams'] =
          190;
      ((payload['reference'] as Map<String, dynamic>)['reference_nutrition']
              as Map<String, dynamic>)['carbs'] =
          44;
      client.resolved = jsonEncode(payload);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'new-plate.jpg',
          description: 'New potatoes composition',
        ),
        languageCode: 'en',
      );
      expect(controller.state.items, isEmpty);
      expect(controller.state.proposal!.name, 'Fresh plate');
      controller.acceptWholePlateProposal();
      final fresh = controller.state.items.single;
      expect(fresh, isNot(same(old)));
      expect(fresh.weightGrams, 190);
      expect(fresh.quantityConfidence, .5);
      expect(fresh.nutritionConfidence, .3);
      expect(fresh.reviewed, isFalse);
      expect(fresh.nutritionForPortion!.carbs, 44);
    },
  );
  test(
    'combined ingredient review goes back to preview without another assignment step',
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
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes',
        ),
        languageCode: 'en',
      );
      controller.chooseMode(MealPhotoMode.itemized);
      controller.assignProduct('potatoes', fixtures.candidate);
      controller.next();
      expect(controller.state.step, MealPhotoStep.amounts);
      controller.back();
      expect(controller.state.step, MealPhotoStep.mode);
      expect(controller.state.items.single.product, same(fixtures.candidate));
    },
  );
  testWidgets(
    'default UI previews only the whole plate; division requires explicit action',
    (tester) async {
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: TestPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes',
        ),
        languageCode: 'en',
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MealPhotoReviewScreen(
            controller: controller,
            capture: const SizedBox(),
            pickProduct: (_) async => null,
            onSaved: (_) {},
          ),
        ),
      );
      expect(find.byType(MealPhotoReferencePreview), findsOneWidget);
      expect(find.byType(MealPhotoAssignmentTile), findsNothing);
      expect(find.text(controller.state.proposal!.name), findsOneWidget);
      expect(find.text('Use whole plate proposal'), findsOneWidget);
      expect(find.text('Divide into ingredients'), findsOneWidget);
      await tester.ensureVisible(find.text('Divide into ingredients'));
      await tester.tap(find.text('Divide into ingredients'));
      await tester.pump();
      expect(controller.state.mode, MealPhotoMode.itemized);
      expect(controller.state.step, MealPhotoStep.assignment);
      expect(find.byType(MealPhotoReferencePreview), findsNothing);
      expect(find.byType(MealPhotoAssignmentTile), findsOneWidget);
    },
  );
  testWidgets(
    'use-whole-plate primary action advances directly to unreviewed weight entry',
    (tester) async {
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
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes',
        ),
        languageCode: 'en',
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MealPhotoReviewScreen(
            controller: controller,
            capture: const SizedBox(),
            pickProduct: (_) async => null,
            onSaved: (_) {},
          ),
        ),
      );
      await tester.ensureVisible(find.text('Use whole plate proposal'));
      await tester.tap(find.text('Use whole plate proposal'));
      await tester.pump();
      expect(controller.state.step, MealPhotoStep.amounts);
      expect(find.byType(MealPhotoAssignmentTile), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      expect(saver.calls, 0);
    },
  );
}
