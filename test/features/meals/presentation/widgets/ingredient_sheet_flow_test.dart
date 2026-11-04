import 'package:diabeatthis/core/domain/model/portion.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_button.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/amount_form.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/confidence_slider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:diabeatthis/features/portions/presentation/widgets/portion_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/regression/catalog_interface_overrides.dart';

const sheetApple = IngredientDraft.existing(
  id: 41,
  name: 'Jabłko',
  carbsPer100g: 12,
  fatPer100g: 0.2,
  fiberPer100g: 0,
  proteinPer100g: 0.3,
  nutritionConfidence: 0.75,
  isReference: false,
  iconAssetPath: 'assets/icons/food/prepared_meal.png',
);
const sheetPiece = PortionSelection.existing(
  id: 1,
  name: 'piece',
  unitHint: 'g',
);

void main() {
  late ProviderContainer container;
  MealIngredientsDraft? result;

  setUp(() {
    result = null;
    container = ProviderContainer(
      overrides: [
        ...catalogSearchInterfaceOverrides(),
        ingredientIconClientProvider.overrideWithValue(SheetIconClient()),
        ingredientsByQueryProvider(
          '',
        ).overrideWith((_) async => [sheetApple.toDomain()]),
        ingredientsByQueryProvider('Nowy jogurt').overrideWith((_) async => []),
        portionsByIngredientByQueryProvider(41, '').overrideWith(
          (_) async => [const Portion(id: 1, name: 'piece', unitHint: 'g')],
        ),
        portionsNotInIngredientByQueryProvider(41, '').overrideWith(
          (_) async => [const Portion(id: 2, name: 'plaster', unitHint: 'g')],
        ),
        portionsByQueryProvider('').overrideWith(
          (_) async => [const Portion(id: 1, name: 'piece', unitHint: 'g')],
        ),
        gramsPerPortionProvider(
          sheetApple,
          sheetPiece,
        ).overrideWith((_) async => 150),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    result = await showAddMealIngredientSheet(
                      context: context,
                      ref: ref,
                    ),
                child: const Text('Open ingredient'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open ingredient'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseApple(WidgetTester tester) async {
    await tester.tap(find.text('Jabłko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wybierz Jabłko'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'search separates two lookup buttons from fixed creation and selection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      expect(find.text('Szukaj po kodzie'), findsOneWidget);
      expect(find.text('Szukaj po zdjęciu'), findsOneWidget);
      expect(find.text('Dodaj przez zdjęcia'), findsNothing);
      expect(find.byType(ConfidenceSlider), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Wybierz składnik'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Utwórz nowy składnik').hitTestable(), findsOneWidget);
      await chooseApple(tester);
      expect(find.text('1 × sztuka = 150 g'), findsOneWidget);
      expect(find.text('Nowa porcja'), findsOneWidget);
      expect(find.text('Dodaj w gramach'), findsOneWidget);
      expect(find.byType(ConfidenceSlider), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved portion uses stored weight, additive halves and shared review before returning',
    (tester) async {
      await open(tester);
      await chooseApple(tester);
      expect(find.byType(AmountForm), findsOneWidget);
      expect(find.byType(IngredientPortionAmountForm), findsNothing);
      final addHalf = find.widgetWithText(ActionChip, '+0,5 sztuki');
      await tester.ensureVisible(addHalf);
      await tester.tap(addHalf);
      await tester.pumpAndSettle();
      await tester.tap(addHalf);
      await tester.pumpAndSettle();
      expect(container.read(mealIngredientAmountDraftProvider), 2);
      await tester.tap(find.widgetWithText(FilledButton, 'Podsumowanie'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(MealIngredientReview), findsOneWidget);
      expect(find.text('2 × sztuka · 300 g'), findsOneWidget);
      expect(find.text('Łączna pewność'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Dodaj składnik'));
      await tester.pumpAndSettle();
      expect(result?.ingredient, sheetApple);
      expect(result?.ingredientPortion.portion, sheetPiece);
      expect(result?.amount, 2);
      expect(result?.quantityConfidence, 0.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'define portion first offers unassigned global names before new name and unit',
    (tester) async {
      await open(tester);
      await chooseApple(tester);
      await tester.tap(find.text('Nowa porcja'));
      await tester.pumpAndSettle();
      expect(find.text('plaster'), findsOneWidget);
      expect(find.text('sztuka'), findsNothing);
      expect(find.byType(PortionForm), findsNothing);
      await tester.tap(find.text('Utwórz nową nazwę porcji'));
      await tester.pumpAndSettle();
      expect(find.byType(PortionForm), findsOneWidget);
      expect(find.text('Jednostka wagi'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual creation retains search name and exposes editable icon and nutrition',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField), 'Nowy jogurt');
      await tester.pumpAndSettle();
      expect(find.text('Utwórz nowy składnik').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Utwórz nowy składnik'));
      await tester.pumpAndSettle();
      expect(find.text('Dodaj przez zdjęcia'), findsOneWidget);
      expect(find.text('Skanuj kod'), findsOneWidget);
      expect(find.text('Danie referencyjne'), findsOneWidget);
      await tester.tap(find.text('Wpisz ręcznie'));
      await tester.pumpAndSettle();
      expect(find.text('Nowy jogurt'), findsOneWidget);
      expect(find.byType(IngredientIconButton), findsOneWidget);
      expect(find.text('Pewność danych odżywczych'), findsOneWidget);
      final carbs = find.widgetWithText(TextFormField, 'Węglowodany');
      await tester.ensureVisible(carbs);
      await tester.enterText(carbs, '12');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Dalej'));
      await tester.pumpAndSettle();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionAddNewSearch,
      );
      expect(find.text('sztuka'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class SheetIconClient implements LocalLlmClient {
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async =>
      const LocalLlmResponse(text: '{"icon":"prepared_meal"}');
}
