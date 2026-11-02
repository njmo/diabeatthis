import 'package:diabeatthis/common/widgets/search_text_field.dart';
import 'package:diabeatthis/core/domain/model/portion.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient_actions.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_filter.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:diabeatthis/features/portions/presentation/widgets/portion_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final initiallyEmpty in [true, false]) {
    testWidgets(
      'portion search stays useful when empty (initial: $initiallyEmpty)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            portionsByQueryProvider('').overrideWith(
              (_) async => initiallyEmpty
                  ? []
                  : [const Portion(id: 1, name: 'piece', unitHint: 'g')],
            ),
            portionsByQueryProvider('missing').overrideWith((_) async => []),
          ],
        );
        addTearDown(container.dispose);
        container.listen(portionFilterProvider, (_, _) {});
        container
            .read(portionFilterProvider.notifier)
            .setFilter(const PortionFilter.byQuery());
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: Scaffold(body: PortionSearch(onCreatePortion: () {})),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(SearchTextField),
          initiallyEmpty ? findsNothing : findsOneWidget,
        );
        if (!initiallyEmpty) {
          await tester.enterText(find.byType(TextField), 'missing');
          await tester.pumpAndSettle();
          expect(find.byType(SearchTextField), findsOneWidget);
        }
        expect(find.byType(OutlinedButton), findsOneWidget);
      },
    );
  }
  testWidgets(
    'gram shortcut is available only when picking an assigned measure',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(addMealIngredientStageProvider, (_, _) {});
      final flow = container.read(addMealIngredientStageProvider.notifier);
      flow.setStage(AddMealIngredientStage.portionAddNewSearch);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const Scaffold(body: AddMealIngredientActions()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dodaj w gramach'), findsNothing);
      flow.setStage(AddMealIngredientStage.definedPortionsSearch);
      await tester.pumpAndSettle();
      expect(find.text('Dodaj w gramach'), findsOneWidget);
    },
  );
}
