import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final isReference in [false, true]) {
    testWidgets(
      'brand is optional and clearing it stores null (reference: $isReference)',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final subscription = container.listen(
          ingredientDraftProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final notifier = container.read(ingredientDraftProvider.notifier);
        notifier.setIsReference(isReference);
        notifier.setBrand('ACME');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: const Scaffold(
                body: SingleChildScrollView(child: IngredientForm()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final brandFinder = find.ancestor(
          of: find.text('Producent (opcjonalnie)'),
          matching: find.byType(TextFormField),
        );
        final field = tester.widget<TextFormField>(brandFinder);
        expect(field.validator!(null), isNull);
        expect(field.validator!(''), isNull);
        expect(field.validator!('   '), isNull);
        expect(field.validator!('ACME'), isNull);
        expect(field.validator!('A'), isNotNull);
        await tester.ensureVisible(brandFinder);
        await tester.enterText(brandFinder, '   ');
        await tester.pumpAndSettle();
        expect(container.read(ingredientDraftProvider).brand, isNull);
        await tester.enterText(brandFinder, '  ACME  ');
        await tester.pumpAndSettle();
        expect(container.read(ingredientDraftProvider).brand, 'ACME');
        await tester.enterText(brandFinder, '');
        await tester.pumpAndSettle();
        expect(container.read(ingredientDraftProvider).brand, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
