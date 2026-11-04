import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_confirmation_tile.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_selection_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  testWidgets(
    'whole plate requires reference acceptance, weight review and explicit save',
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
          description: 'Potatoes and other meal ingredients',
        ),
        languageCode: 'en',
      );
      int? saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MealPhotoReviewScreen(
            controller: controller,
            capture: const SizedBox(),
            pickProduct: (_) async => null,
            onSaved: (id) => saved = id,
          ),
        ),
      );
      await tester.ensureVisible(find.text('Use whole plate proposal'));
      await tester.tap(find.text('Use whole plate proposal'));
      await tester.pump();
      expect(find.text('Assign product'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );

      expect(saver.calls, 0);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(saver.calls, 0);
      expect(find.text('30.0 g'), findsOneWidget);
      expect(find.text('3.0 g'), findsOneWidget);
      expect(find.text('Fiber'), findsOneWidget);
      expect(find.textContaining('Weight confidence: Medium'), findsNothing);
      await tester.ensureVisible(find.byType(MealPhotoConfirmationTile));
      await tester.tap(
        find.descendant(
          of: find.byType(MealPhotoConfirmationTile),
          matching: find.text('Cooked potatoes'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Weight confidence:'), findsNothing);
      final summaryItem = find.byType(MealPhotoConfirmationTile);
      expect(
        find.descendant(of: summaryItem, matching: find.byType(ExpansionTile)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: summaryItem,
          matching: find.text('Cooked potatoes'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summaryItem, matching: find.text('150 g')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summaryItem,
          matching: find.byType(MealPhotoSelectionOrigin),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm reviewed proposal'));
      await tester.pump();
      expect(saver.calls, 1);
      saver.result.complete(42);
      await tester.pumpAndSettle();
      expect(saved, 42);
      expect(saver.accepted!.items.single.nutritionForPortion!.carbs, 30);
    },
  );

  testWidgets(
    'invalid physical nutrition keeps amount step visible with a recoverable localized error',
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
          description: 'Potatoes and other meal ingredients',
        ),
        languageCode: 'en',
      );
      controller.chooseMode(MealPhotoMode.reference);
      controller.acceptReference('plate');
      controller.next();
      controller.setAmount(
        'plate',
        grams: 10,
        quantityConfidence: .5,
        nutritionConfidence: .5,
        reviewed: true,
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
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(controller.state.step, MealPhotoStep.amounts);
      expect(
        find.textContaining('Check the weight and nutrition'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'product picker response from a discarded proposal cannot assign to its replacement',
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
          description: 'Potatoes and other meal ingredients',
        ),
        languageCode: 'en',
      );
      controller.chooseMode(MealPhotoMode.itemized);
      final selection = Completer<MealPhotoCandidate?>();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MealPhotoReviewScreen(
            controller: controller,
            capture: const SizedBox(),
            pickProduct: (_) => selection.future,
            onSaved: (_) {},
          ),
        ),
      );
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign product'));
      await tester.pumpAndSettle();
      await tester.pump();
      controller.cancel();
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'other.jpg',
          description: 'Potatoes and other meal ingredients',
        ),
        languageCode: 'en',
      );
      controller.chooseMode(MealPhotoMode.itemized);
      await tester.pump();
      selection.complete(fixtures.candidate);
      await tester.pump();
      expect(controller.state.items.single.product, isNull);
    },
  );

  for (final scenario in [
    (
      protein: 0.0,
      expected: 'The ingredient must have carbohydrate, fat or protein values.',
    ),
    (
      protein: 2.0,
      expected:
          'A meal must contain net carbohydrates or extended carbs from fat and protein.',
    ),
  ]) {
    testWidgets(
      'nutrition policy failure shows its precise localized reason: ${scenario.protein}',
      (tester) async {
        final payload = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
        (payload['reference']
            as Map<String, dynamic>)['reference_nutrition'] = {
          'carbs': 0,
          'fiber': 0,
          'fat': 0,
          'protein': scenario.protein,
          'carbs_label_mode': 'eu',
        };
        final client = TestPhotoClient()..resolved = jsonEncode(payload);
        final saver = TestPhotoSaver();
        final controller = MealPhotoController(
          propose: ProposeMealFromPhotoUseCase(
            client: client,
            candidates: TestPhotoCandidates(),
          ),
          saver: saver,
        );
        addTearDown(controller.dispose);
        await controller.generate(
          const MealPhotoInput(
            mealPhotoPath: 'plate.jpg',
            description: 'Potatoes and other meal ingredients',
          ),
          languageCode: 'en',
        );
        controller.chooseMode(MealPhotoMode.reference);
        controller.acceptReference('plate');
        controller.next();
        controller.setAmount(
          'plate',
          grams: 150,
          quantityConfidence: .5,
          nutritionConfidence: .5,
          reviewed: true,
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
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(controller.state.step, MealPhotoStep.amounts);
        expect(saver.calls, 0);
        expect(find.text(scenario.expected), findsOneWidget);
        expect(
          find.textContaining('Check the weight and nutrition'),
          findsNothing,
        );
      },
    );
  }
}
