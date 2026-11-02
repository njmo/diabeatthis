import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_detail_components.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_nutrition_analysis_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';

void main() {
  for (final reportedAmount in <double?>[null, 50]) {
    testWidgets(
      'interrupted ingredient displays only reported consumption $reportedAmount',
      (tester) async {
        final details = interruptedDetails(reportedAmount);
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MealNutritionAnalysisSection(details: details),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tileFinder = find.byType(MealIngredientTile);
        expect(
          tester
              .widget<MealIngredientTile>(tileFinder)
              .usePlannedConsumptionFallback,
          isFalse,
        );
        final tile = tester.widget<ExpansionTile>(
          find
              .descendant(of: tileFinder, matching: find.byType(ExpansionTile))
              .first,
        );
        final context = tester.element(tileFinder);
        final text = (tile.subtitle! as Text).data!;
        expect(text, contains(context.lang.mealPlanInline('100')));
        expect(
          text,
          contains(
            context.lang.mealConsumedInline(
              reportedAmount == null ? '-' : '50',
            ),
          ),
        );
        expect(text, isNot(contains(context.lang.mealConsumedInline('100'))));

        final title = find.descendant(
          of: tileFinder,
          matching: find.text('Rice'),
        );
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
        final rows = tester.widgetList<MealInfoRow>(
          find.descendant(of: tileFinder, matching: find.byType(MealInfoRow)),
        );
        expect(
          rows
              .singleWhere(
                (row) => row.label == context.lang.mealConsumedAmountLabel,
              )
              .value,
          reportedAmount == null ? '-' : '50',
        );
        expect(
          rows
              .singleWhere(
                (row) => row.label == context.lang.mealConsumedMassLabel,
              )
              .value,
          reportedAmount == null ? '-' : '50g',
        );
        expect(
          rows
              .singleWhere(
                (row) => row.label == context.lang.mealPlannedMassLabel,
              )
              .value,
          '100g',
        );
        final breakdown = find.descendant(
          of: find.byType(MealContributionBreakdown),
          matching: find.byType(MealInfoRow),
        );
        expect(
          breakdown,
          reportedAmount == null ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

MealDetailsData interruptedDetails(double? reportedAmount) {
  final at = DateTime(2026, 11, 1, 12);
  const nutrition = IngredientNutritionData(
    carbsPer100g: 20,
    fatPer100g: 1,
    fiberPer100g: 0,
    proteinPer100g: 2,
    carbsLabelMode: CarbsLabelMode.eu,
    nutritionConfidence: 1,
    effectiveAt: null,
  );
  return MealDetailsData(
    meal: MealRecordData(
      id: 1,
      name: 'Lunch',
      status: 'interrupted',
      plannedAt: at,
      summarizedAt: null,
      mealTemplateId: null,
      basedOnMealId: null,
      notes: null,
      createdAt: at,
      updatedAt: at,
      isSynced: false,
    ),
    advisorDecision: null,
    plannedSnapshot: null,
    consumedSnapshot: null,
    statusHistory: [],
    ingredients: [
      MealIngredientDetailsData(
        mealIngredientId: 1,
        ingredientId: 1,
        ingredientName: 'Rice',
        entryType: 'planned',
        portionLabel: 'g',
        plannedAmount: 100,
        consumedAmount: reportedAmount,
        quantityConfidence: 1,
        consumedConfidence: reportedAmount == null ? null : 1,
        plannedTotalGrams: 100,
        consumedTotalGrams: reportedAmount ?? 100,
        prepMethod: null,
        notes: null,
        createdAt: at,
        updatedAt: at,
        currentNutrition: nutrition,
        plannedNutrition: nutrition,
        consumedNutrition: nutrition,
        plannedNutritionDiffersFromCurrent: false,
        consumedNutritionDiffersFromCurrent: false,
        historicalNutritionUnavailable: false,
      ),
    ],
  );
}
