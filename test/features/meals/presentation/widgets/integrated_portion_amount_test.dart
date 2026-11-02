import 'package:diabeatthis/core/domain/model/portion.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/ingredient_amount_portions.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import 'ingredient_sheet_flow_test.dart' show sheetApple, sheetPiece;

void main() {
  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      portionsByIngredientByQueryProvider(41, '').overrideWith(
        (_) async => [
          const Portion(id: 1, name: 'piece', unitHint: 'g'),
          const Portion(id: 2, name: 'small', unitHint: 'g'),
          const Portion(id: 3, name: 'large', unitHint: 'g'),
        ],
      ),
      gramsPerPortionProvider(
        sheetApple,
        sheetPiece,
      ).overrideWith((_) async => 150),
      gramsPerPortionProvider(
        sheetApple,
        const PortionSelection.existing(id: 2, name: 'small', unitHint: 'g'),
      ).overrideWith((_) async => 75),
      gramsPerPortionProvider(
        sheetApple,
        const PortionSelection.existing(id: 3, name: 'large', unitHint: 'g'),
      ).overrideWith((_) async => 200),
    ],
  );

  test(
    'ingredient opens directly with assigned portion and retains new definition across measure changes',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);
      container.listen(addMealIngredientStageProvider, (_, _) {});
      final flow = container.read(addMealIngredientStageProvider.notifier);
      container
          .read(ingredientDraftProvider.notifier)
          .overrideDraft(sheetApple);
      await flow.nextStage();
      await flow.integrateAssignedPortions();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.amountForm,
      );
      expect(
        container.read(mealIngredientsDraftProvider).ingredientPortion.portion,
        sheetPiece,
      );
      final confidence = container.read(mealIngredientConfidenceDraftProvider);
      flow.defineInlinePortion();
      const newPortion = PortionSelection.draft(
        name: 'custom piece',
        unitHint: 'g',
      );
      container.read(portionDraftProvider.notifier).overrideDraft(newPortion);
      await flow.nextStage();
      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(85);
      await flow.nextStage();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.amountForm,
      );
      expect(flow.inlineDefinedPortions, contains(newPortion));
      flow.selectInlinePortion(const PortionSelection.empty());
      flow.selectInlinePortion(newPortion);
      expect(
        container.read(mealIngredientsDraftProvider).ingredientPortion.amount,
        85,
      );
      expect(container.read(mealIngredientAmountDraftProvider), 0);
      expect(container.read(mealIngredientConfidenceDraftProvider), confidence);
    },
  );

  testWidgets('new portion is the last horizontally scrolled card', (
    tester,
  ) async {
    final container = createContainer();
    addTearDown(container.dispose);
    container.listen(addMealIngredientStageProvider, (_, _) {});
    final flow = container.read(addMealIngredientStageProvider.notifier);
    container.read(ingredientDraftProvider.notifier).overrideDraft(sheetApple);
    await flow.nextStage();
    await flow.integrateAssignedPortions();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: const Scaffold(
            body: SizedBox(width: 320, child: IngredientAmountPortions()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Nowa porcja').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Nowa porcja'));
    await tester.pumpAndSettle();
    expect(
      container.read(addMealIngredientStageProvider),
      AddMealIngredientStage.portionAddNewSearch,
    );
    expect(tester.takeException(), isNull);
  });
}
