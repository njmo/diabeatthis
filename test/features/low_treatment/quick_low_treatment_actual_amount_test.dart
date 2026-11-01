import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/core/domain/model/portion.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/features/low_treatment/data/mappers/quick_low_treatment_item_mapper.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/quick_low_treatment_item_provider.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final portionBased in [true, false]) {
    testWidgets(
      'controls actual ${portionBased ? 'portions' : 'grams'} instead of a shortcut multiplier',
      (tester) async {
        final item = QuickLowTreatmentItem(
          id: 1,
          name: 'TEST Milk',
          ingredient: const Ingredient(
            id: 1,
            name: 'TEST Milk',
            carbsPer100g: 5,
            fatPer100g: 0,
            proteinPer100g: 0,
            fiberPer100g: 0,
            nutritionConfidence: 1,
            isReference: false,
          ),
          portion: portionBased
              ? const Portion(id: 1, name: 'szklanka', unitHint: 'szt.')
              : null,
          amount: portionBased ? 2 : 100,
          sortOrder: 1,
          gramsPerPortion: portionBased ? 200 : null,
        );
        double? amount;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              quickLowTreatmentItemsProvider.overrideWith(
                (ref) => Stream.value([item]),
              ),
            ],
            child: localizedMaterialApp(
              home: Scaffold(
                body: QuickLowTreatmentSelector(
                  onSelected: (selected, multiplier) => amount = selected
                      .toMealIngredientDraft(quantity: multiplier)
                      .amount,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        var stepper = tester.widget<QuickLowTreatmentQuantityStepper>(
          find.byType(QuickLowTreatmentQuantityStepper),
        );
        expect(stepper.value, item.amount);
        expect(stepper.unit, portionBased ? 'szklanka' : 'g');
        expect(amount, item.amount);
        await tester.tap(find.byTooltip('Zwiększ ilość'));
        await tester.pumpAndSettle();
        expect(amount, closeTo(item.amount + 0.5, 0.0000001));
        stepper = tester.widget<QuickLowTreatmentQuantityStepper>(
          find.byType(QuickLowTreatmentQuantityStepper),
        );
        expect(stepper.value, closeTo(item.amount + 0.5, 0.0000001));
        await tester.tap(
          find.descendant(
            of: find.byType(QuickLowTreatmentQuantityStepper),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '3,5');
        await tester.tap(find.text('Zatwierdź'));
        await tester.pumpAndSettle();
        expect(amount, closeTo(3.5, 0.0000001));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
