import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_portion_suggestions_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import 'package:diabeatthis/features/ingredients/presentation/services/ingredient_barcode_scanner.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_creation_methods.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/regression/catalog_interface_overrides.dart';

void main() {
  final lang = AppLocalizationsPl();

  testWidgets(
    'local code opens stored portions directly without a creation prompt',
    (tester) async {
      const saved = Ingredient(
        id: 21,
        name: 'Saved apple',
        carbsPer100g: 12,
        fatPer100g: 0.2,
        fiberPer100g: 2,
        proteinPer100g: 0.3,
        nutritionConfidence: 0.75,
        isReference: false,
        iconAssetPath: 'assets/icons/food/apple.png',
      );
      final container = lookupFlowContainer(
        const IngredientBarcodeScanOutcome.existingIngredient(saved),
      );
      addTearDown(container.dispose);
      await openLookupFlow(tester, container);

      await tester.tap(find.text(lang.ingredientSearchByCode));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.amountForm,
      );
      expect(
        container
            .read(mealIngredientsDraftProvider)
            .ingredient
            .getIngredientIdOrNull(),
        21,
      );
      expect(
        container
            .read(mealIngredientsDraftProvider)
            .ingredient
            .nutritionConfidence,
        0.75,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'external code requires confirmation then passes nutrition and portion suggestions',
    (tester) async {
      const draft = IngredientDraft.draft(
        name: 'Imported yogurt',
        carbsPer100g: 5,
        fatPer100g: 3,
        fiberPer100g: 0,
        proteinPer100g: 4,
        nutritionConfidence: 0.25,
        isReference: false,
        barcode: '5900385503415',
        iconAssetPath: 'assets/icons/food/yogurt.png',
      );
      const portion = RecognizedPortion(
        name: 'Cup',
        unitHint: 'portion',
        grams: 150,
        source: 'open_food_facts',
      );
      final container = lookupFlowContainer(
        const IngredientBarcodeScanOutcome.newDraft(draft, portions: [portion]),
      );
      addTearDown(container.dispose);
      await openLookupFlow(tester, container);

      await tester.tap(find.text(lang.ingredientSearchByCode));
      await tester.pumpAndSettle();
      expect(find.text(lang.ingredientCodeCreateTitle), findsOneWidget);
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientSearch,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, lang.ingredientCreateNew),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientForm,
      );
      expect(container.read(ingredientDraftProvider), draft);
      expect(container.read(ingredientPortionSuggestionsProvider), [portion]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed code keeps creation available and prefills the barcode in manual entry',
    (tester) async {
      final container = lookupFlowContainer(
        const IngredientBarcodeScanOutcome.failed(null),
      );
      addTearDown(container.dispose);
      await openLookupFlow(tester, container);

      await tester.tap(find.text(lang.ingredientSearchByCode));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang.commonCloseTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang.ingredientCreateNew));
      await tester.pumpAndSettle();
      expect(find.byType(IngredientCreationMethods), findsOneWidget);
      expect(find.text(lang.ingredientCreatePhotos), findsOneWidget);
      await tester.tap(find.text(lang.ingredientCreateManual));
      await tester.pumpAndSettle();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientForm,
      );
      expect(container.read(ingredientDraftProvider).barcode, '5900385503415');
      expect(tester.takeException(), isNull);
    },
  );
}

ProviderContainer lookupFlowContainer(IngredientBarcodeScanOutcome outcome) {
  return ProviderContainer(
    overrides: [
      ...catalogSearchInterfaceOverrides(),
      ingredientBarcodeScannerProvider.overrideWithValue(
        const LookupFlowBarcodeScanner(),
      ),
      ingredientBarcodeLookupControllerProvider.overrideWith(
        () => LookupFlowBarcodeController(outcome),
      ),
      ingredientsByQueryProvider('').overrideWith((_) async => []),
      portionsByIngredientByQueryProvider(21, '').overrideWith((_) async => []),
    ],
  );
}

Future<void> openLookupFlow(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedMaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  showAddMealIngredientSheet(context: context, ref: ref),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

class LookupFlowBarcodeScanner extends IngredientBarcodeScanner {
  const LookupFlowBarcodeScanner();

  @override
  Future<String?> scan(BuildContext context) async => '5900385503415';
}

class LookupFlowBarcodeController extends IngredientBarcodeLookupController {
  final IngredientBarcodeScanOutcome outcome;
  LookupFlowBarcodeController(this.outcome);

  @override
  Future<IngredientBarcodeScanOutcome> scan(String barcode) async {
    state = AsyncData(outcome);
    return outcome;
  }
}
