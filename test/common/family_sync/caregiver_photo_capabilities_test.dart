import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/ports/meal_photo_candidate_repository.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_ingredient_actions.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meal_photo/meal_photo_controller_test.dart'
    show TestPhotoClient, TestPhotoSaver;
import 'family_photo_plan_saver_test.dart' show candidate, item;

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

class EmptyFamilyPhotoCandidates implements MealPhotoCandidateRepository {
  @override
  Future<List<MealPhotoCandidate>> search(
    String query, {
    required String languageCode,
    int limit = 8,
  }) async => [];
}

void main() {
  test(
    'caregiver does not automatically accept an unmatched reference',
    () async {
      final reference = MealPhotoItem(
        id: 'ref',
        name: 'Apple',
        searchQuery: 'apple',
        kind: MealPhotoItemKind.proposedReference,
        recognitionConfidence: .8,
        quantityConfidence: .8,
        nutritionConfidence: .7,
        referenceNutrition: candidate().nutritionPer100g,
      );
      final controller = MealPhotoController(
        allowIngredientCreation: false,
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: EmptyFamilyPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      controller.emit(
        MealPhotoState(
          step: MealPhotoStep.mode,
          proposal: MealPhotoProposal(
            name: 'Lunch',
            itemized: [reference],
            reference: reference,
            rawResponse: '',
          ),
        ),
      );
      await controller.divideIntoIngredients(languageCode: 'en');
      expect(controller.state.items.single.referenceAccepted, isFalse);
      expect(controller.state.items.single.assigned, isFalse);
      expect(controller.next, throwsStateError);
      expect(
        () => controller.chooseMode(MealPhotoMode.reference),
        throwsStateError,
      );
    },
  );

  testWidgets('caregiver photo cannot start whole-plate ingredient creation', (
    tester,
  ) async {
    var divides = 0;
    await tester.pumpWidget(
      host(
        MealPhotoModeSelector(
          proposal: MealPhotoProposal(
            name: 'Lunch',
            itemized: [item],
            reference: MealPhotoItem(
              id: 'whole',
              name: 'Apple',
              searchQuery: 'apple',
              kind: MealPhotoItemKind.proposedReference,
              recognitionConfidence: .8,
              quantityConfidence: .8,
              nutritionConfidence: .8,
              referenceNutrition: candidate().nutritionPer100g,
              estimatedWeightGrams: 50,
            ),
            rawResponse: '',
          ),
          allowIngredientCreation: false,
          onUseWholePlate: () => fail('Creation must be hidden'),
          onEditReference: () => fail('Creation must be hidden'),
          onDivide: () => divides++,
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.tap(find.byIcon(Icons.call_split));
    expect(divides, 1);
  });
  testWidgets(
    'caregiver ingredient menu offers product selection without reference creation',
    (tester) async {
      final reference = MealPhotoItem(
        id: 'ref',
        name: 'Apple',
        searchQuery: 'apple',
        kind: MealPhotoItemKind.proposedReference,
        recognitionConfidence: .8,
        quantityConfidence: .8,
        nutritionConfidence: .7,
        referenceNutrition: candidate().nutritionPer100g,
      );
      await tester.pumpWidget(
        host(
          MealPhotoIngredientActions(
            item: MealPhotoReviewItem(
              proposal: reference,
              weightGrams: 50,
              quantityConfidence: .8,
              nutritionConfidence: .7,
            ),
            allowProduct: true,
            allowIngredientCreation: false,
            onAssign: () {},
            onReference: () => fail('Reference must be hidden'),
            onCreateReference: () => fail('Creation must be hidden'),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<MealPhotoIngredientAction>));
      await tester.pumpAndSettle();
      final choices = tester
          .widgetList<PopupMenuItem<MealPhotoIngredientAction>>(
            find.byType(PopupMenuItem<MealPhotoIngredientAction>),
          );
      expect(choices.map((c) => c.value), [MealPhotoIngredientAction.product]);
    },
  );
}
