import 'package:diabeatthis/common/widgets/value_change_row.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_history_entry_data.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_nutrition_values.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_edit_mode.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_history_change_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'reference history shows extended carbs and split, with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: IngredientHistoryChangeCard(
                  entry: IngredientHistoryEntryData(
                    id: 1,
                    ingredientId: 1,
                    carbsPer100g: 20,
                    fatPer100g: 4,
                    fiberPer100g: 0,
                    proteinPer100g: 5,
                    nutritionConfidence: 0.5,
                    createdAt: DateTime(2026, 10, 30),
                  ),
                  after: const IngredientNutritionValues(
                    carbs: 20,
                    fat: 5,
                    fiber: 0,
                    protein: 8,
                    confidence: 0.5,
                  ),
                  isReference: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rows = tester
          .widgetList<ValueChangeRow>(find.byType(ValueChangeRow))
          .toList();
      expect(rows, hasLength(2));
      expect(rows.first.before, '5.60 g');
      expect(rows.first.after, '7.70 g');
      expect(rows.last.label, 'Podział węglowodanów przedłużonych');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reference editor keeps both carbohydrate inputs accessible with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(ingredientDraftProvider.notifier)
          .overrideDraft(
            const IngredientDraft.existing(
              id: 1,
              name: 'Kurczak z ziemniakami',
              carbsPer100g: 20,
              fatPer100g: 4,
              fiberPer100g: 0,
              proteinPer100g: 5,
              nutritionConfidence: 0.5,
              isReference: true,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(child: IngredientEditMode()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Węglowodany proste (carbs)'), findsOneWidget);
      expect(find.text('Węglowodany przedłużone (ecarbs)'), findsOneWidget);
    },
  );
}
