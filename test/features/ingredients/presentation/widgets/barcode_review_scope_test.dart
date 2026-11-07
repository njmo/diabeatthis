import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/barcode_ingredient_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'barcode draft review is isolated and incomplete facts require confirmation',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(ingredientDraftProvider, (_, _) {});
      addTearDown(subscription.close);
      final before = container.read(ingredientDraftProvider);
      IngredientDraft? selected;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await showBarcodeIngredientReviewSheet(
                      context,
                      draft: const IngredientDraft.draft(
                        name: 'Yogurt',
                        brand: 'Brand',
                        barcode: '5901234123457',
                        iconAssetPath: 'assets/icons/food/prepared_meal.png',
                        carbsPer100g: 5,
                        fiberPer100g: 0,
                        proteinPer100g: 8,
                        fatPer100g: 3,
                        nutritionConfidence: .8,
                        isReference: false,
                      ),
                      needsReview: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final use = find.widgetWithText(FilledButton, 'Użyj produktu');
      expect(tester.widget<FilledButton>(use).onPressed, isNull);
      final checkbox = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<FilledButton>(use).onPressed, isNotNull);
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(selected?.name, 'Yogurt');
      expect(selected?.carbsPer100g, 5);
      expect(container.read(ingredientDraftProvider), before);
      expect(tester.takeException(), isNull);
    },
  );
}
