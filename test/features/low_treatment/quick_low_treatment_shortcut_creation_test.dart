import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_selector.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_tile.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'TEST Juice',
            carbsPer100g: 10,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
            iconAssetPath: const Value('assets/icons/food/prepared_meal.png'),
          ),
        );
    await db
        .into(db.portion)
        .insert(PortionCompanion.insert(name: 'piece', unitHint: 'g'));
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ingredientIconClientProvider.overrideWithValue(ShortcutIconClient()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> openShortcut(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuickLowTreatmentSelector(onSelected: (_, _) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Dodaj skrót'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMealIngredient), findsOneWidget);
  }

  Future<void> confirmShortcut(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Podsumowanie'));
    await tester.pumpAndSettle();
    expect(find.byType(MealIngredientReview), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Dodaj składnik'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMealIngredient), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byType(QuickLowTreatmentTile), findsOneWidget);
    expect(find.text(name), findsWidgets);
    final items = await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems();
    expect(items, hasLength(1));
    expect(items.single.name, name);
    expect(items.single.amount, greaterThan(0));
  }

  testWidgets('adding an existing ingredient creates a visible shortcut', (
    tester,
  ) async {
    await openShortcut(tester);
    await tester.tap(find.text('TEST Juice'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Wybierz TEST Juice'));
    await tester.pumpAndSettle();
    await confirmShortcut(tester, 'TEST Juice');
  });

  testWidgets('creating a new ingredient creates a visible shortcut', (
    tester,
  ) async {
    await openShortcut(tester);
    await tester.enterText(find.byType(TextFormField), 'TEST New glucose');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utwórz nowy składnik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wpisz ręcznie'));
    await tester.pumpAndSettle();
    final carbs = find.widgetWithText(TextFormField, 'Węglowodany');
    await tester.ensureVisible(carbs);
    await tester.enterText(carbs, '100');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Dalej'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sztuka'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Dalej'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '+50 g'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Dalej'));
    await tester.pumpAndSettle();
    await confirmShortcut(tester, 'TEST New glucose');
  });
}

class ShortcutIconClient implements LocalLlmClient {
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async =>
      const LocalLlmResponse(text: '{"icon":"prepared_meal"}');
}
