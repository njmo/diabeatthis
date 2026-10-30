import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/create_ingredient_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'standalone creation saves the ingredient and restores the previous draft',
    (tester) async {
      IngredientDraft? saved;
      final container = ProviderContainer(
        overrides: [
          insertIngredientProvider.overrideWith((ref, ingredient) async {
            saved = ingredient;
            return const Ingredient(
              id: 1,
              name: 'Ryż',
              carbsPer100g: 78,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 0.25,
              isReference: false,
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(ingredientDraftProvider, (_, _) {});
      addTearDown(subscription.close);
      container.read(ingredientDraftProvider.notifier).setName('Earlier draft');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showCreateIngredientSheet(context, ref),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      Finder field(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );
      expect(find.text('Podaj nazwę składnika'), findsNothing);
      await tester.enterText(field('Nazwa'), 'Ryż');
      await tester.ensureVisible(field('Węglowodany'));
      await tester.enterText(field('Węglowodany'), '78');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Zapisz składnik'));
      await tester.tap(find.text('Zapisz składnik'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Ryż');
      expect(saved?.carbsPer100g, 78);
      expect(find.byType(CreateIngredientSheet), findsNothing);
      expect(container.read(ingredientDraftProvider).name, 'Earlier draft');
      expect(tester.takeException(), isNull);
    },
  );
}
