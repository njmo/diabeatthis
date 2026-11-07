import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/barcode_ingredient_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'manual review can discard without confirming or changing the original draft at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final subscription = container.listen(
          ingredientDraftProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final before = container.read(ingredientDraftProvider);
        IngredientDraft? result;
        var returned = false;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(390, 844),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showBarcodeIngredientReviewSheet(
                          context,
                          draft: const IngredientDraft.draft(
                            name: 'Yogurt',
                            barcode: '5901234123457',
                            iconAssetPath:
                                'assets/icons/food/prepared_meal.png',
                            carbsPer100g: 5,
                            fiberPer100g: 0,
                            proteinPer100g: 8,
                            fatPer100g: 3,
                            nutritionConfidence: .5,
                            isReference: false,
                          ),
                          needsReview: true,
                        );
                        returned = true;
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Odczytaj etykietę z AI'), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Użyj produktu'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Odrzuć produkt'));
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(result, isNull);
        expect(container.read(ingredientDraftProvider), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
