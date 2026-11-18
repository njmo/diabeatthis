import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_reference_macro_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'IngredientReferenceMacroForm takes eCarbs in grams and shows dynamic WBT helper',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize reference draft
      container.read(ingredientDraftProvider.notifier).setIsReference(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(
                child: IngredientReferenceMacroForm(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder field(String label) => find.ancestor(
            of: find.text(label),
            matching: find.byType(TextFormField),
          );

      expect(find.text('Węglowodany proste (carbs)'), findsOneWidget);
      expect(find.text('Węglowodany przedłużone (ecarbs)'), findsOneWidget);
      expect(find.text('= 0.0 WBT (1 WBT = 10 g)'), findsOneWidget);

      // Enter 25 g of eCarbs
      await tester.enterText(
        field('Węglowodany przedłużone (ecarbs)'),
        '25',
      );
      await tester.pumpAndSettle();

      // Helper text should update dynamically to 2.5 WBT
      expect(find.text('= 2.5 WBT (1 WBT = 10 g)'), findsOneWidget);

      final draft = container.read(ingredientDraftProvider);
      // 25 g eCarbs = 250 kcal. Default 50% split: 125 kcal fat (13.89 g), 125 kcal protein (31.25 g)
      expect(draft.fatPer100g, closeTo(13.89, 0.05));
      expect(draft.proteinPer100g, closeTo(31.25, 0.05));
    },
  );
}
