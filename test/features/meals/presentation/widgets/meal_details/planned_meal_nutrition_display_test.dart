import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/nutrition/meal_nutrition_totals.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/nutrient_summary_chart.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_nutrition_analysis_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_snapshot_comparison_row.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_snapshots_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows planned nutrients and chart without inventing consumed values',
    (tester) async {
      final now = DateTime(2026, 11, 1, 12);
      final details = MealDetailsData(
        meal: MealRecordData(
          id: 1,
          name: 'Planned meal',
          status: 'planned',
          plannedAt: now,
          summarizedAt: null,
          mealTemplateId: null,
          basedOnMealId: null,
          notes: null,
          createdAt: now,
          updatedAt: now,
          isSynced: false,
        ),
        advisorDecision: null,
        ingredients: const [],
        plannedSnapshot: null,
        consumedSnapshot: null,
        statusHistory: const [],
        plannedPreviewNutrition: const MealNutritionTotals(
          totalGrams: 150,
          totalCarbsG: 30,
          totalFiberG: 3,
          totalNetCarbsG: 27,
          totalFatG: 7.5,
          totalProteinG: 6,
          totalCaloriesKcal: 199.5,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MealNutritionAnalysisSection(details: details),
                  MealSnapshotsSection(details: details),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summary = find.byType(MealNutritionMacroSummary);
      for (final value in [
        '30g',
        '3g',
        '27g',
        '7.5g',
        '6g',
        '150g',
        '199.5kcal',
      ]) {
        expect(
          find.descendant(of: summary, matching: find.text(value)),
          findsOneWidget,
        );
      }
      final chart = tester.widget<NutrientSummaryChart>(
        find.byType(NutrientSummaryChart),
      );
      expect(chart.macros.carbsTotal, 30);
      expect(chart.macros.netCarbsTotal, 27);
      expect(chart.macros.fatTotal, 8);
      expect(chart.macros.proteinTotal, 6);

      final comparisonSection = find.byType(MealSnapshotsSection);
      final comparisonTile = find.descendant(
        of: comparisonSection,
        matching: find.byType(ExpansionTile),
      );
      await tester.ensureVisible(comparisonTile);
      await tester.tap(comparisonTile);
      await tester.pumpAndSettle();

      final rows = tester
          .widgetList<MealSnapshotComparisonRow>(
            find.byType(MealSnapshotComparisonRow),
          )
          .toList();
      expect(rows, hasLength(6));
      expect(rows.map((widget) => widget.row.plannedValue), [
        30,
        7.5,
        6,
        3,
        199.5,
        150,
      ]);
      for (final widget in rows) {
        expect(widget.row.consumedValue, isNull);
        expect(widget.row.difference, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
