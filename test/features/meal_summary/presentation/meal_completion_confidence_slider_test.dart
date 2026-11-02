import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/common/widgets/confidence_slider.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_ingredient_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  Future<ProviderContainer> open(
    WidgetTester tester, {
    bool showConfidence = false,
    bool addOnOnly = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        mealSummaryControllerProvider.overrideWith(
          ConfidenceMealController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealCompletionIngredientRow(
                mealId: 1,
                mealIngredientId: 7,
                showConfidence: showConfidence,
                addOnOnly: addOnOnly,
                onInputValidityChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  MealSummaryItemDraft item(ProviderContainer container) => container
      .read(mealSummaryControllerProvider(1))
      .requireValue
      .itemsById[7]!;

  testWidgets(
    'fresh completion preserves preset certainty without an extra control',
    (tester) async {
      final container = await open(tester);
      expect(find.byType(ConfidenceSlider), findsNothing);
      expect(item(container).consumedConfidence, 0.75);
      expect(item(container).consumedAmount, 1.5);
    },
  );

  testWidgets(
    'late completion exposes confidence directly and changes no quantity',
    (tester) async {
      final container = await open(tester, showConfidence: true);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Jak dobrze to pamiętasz?'), findsOneWidget);
      final control = tester.widget<ConfidenceSlider>(
        find.byType(ConfidenceSlider),
      );
      expect(control.value, ConfidenceLevel.high);
      control.onChanged(ConfidenceLevel.medium);
      await tester.pumpAndSettle();
      expect(item(container).consumedConfidence, 0.5);
      expect(item(container).consumedAmount, 1.5);
    },
  );

  testWidgets(
    'manual add-on cannot reduce the reported amount and records fresh certainty',
    (tester) async {
      final container = await open(tester, addOnOnly: true);
      final amount = tester.widget<FriendlyAmountSelector>(
        find.byType(FriendlyAmountSelector),
      );
      expect(amount.min, 1.5);
      expect(find.text('Łącznie z dokładką'), findsOneWidget);
      expect(find.text('Nic'), findsNothing);
      expect(find.text('Połowa'), findsNothing);
      amount.onChanged(2);
      await tester.pumpAndSettle();
      expect(item(container).consumedAmount, 2);
      expect(item(container).consumedConfidence, 1);
    },
  );
}

class ConfidenceMealController extends MealSummaryControllerNotifier {
  @override
  Future<MealSummaryDraft> build(int mealId) async => const MealSummaryDraft(
    mealId: 1,
    mealStatus: 'bolused-eating',
    itemIds: [7],
    itemsById: {
      7: MealSummaryItemDraft(
        name: 'Meatball',
        mealIngredientId: 7,
        plannedAmount: 1,
        reportedAmount: 1.5,
        consumedAmount: 1.5,
        consumedConfidence: 0.75,
        amountLabel: 'szt.',
        netCarbsPerAmount: 4,
      ),
    },
    extraItems: [],
  );
}
