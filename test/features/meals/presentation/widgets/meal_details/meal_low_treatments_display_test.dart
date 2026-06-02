import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_header.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_low_treatments_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows low treatment chip and section for linked treatments', (
    tester,
  ) async {
    final details = mealDetailsWithLowTreatment();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MealHeader(state: MealPageState(details: details)),
              MealLowTreatmentsSection(details: details),
            ],
          ),
        ),
      ),
    );

    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('Dosłodzono')),
      findsOneWidget,
    );
    expect(find.text('Dosłodzono po 45 min'), findsOneWidget);
    expect(find.text('Dosłodzenia'), findsOneWidget);
    expect(find.text('12:45 • po 45 min'), findsOneWidget);
    expect(find.text('Niski cukier • Dashboard'), findsOneWidget);
    expect(find.text('Glukoza: 10g'), findsOneWidget);
    expect(
      find.text('Razem 10g netto • sugestia 12g • w 15 min'),
      findsOneWidget,
    );
  });
}

MealDetailsData mealDetailsWithLowTreatment() {
  final mealTime = DateTime(2026, 5, 24, 12);
  final treatmentTime = mealTime.add(const Duration(minutes: 45));

  return MealDetailsData(
    meal: mealRecord(
      id: 1,
      name: 'Obiad',
      plannedAt: mealTime,
      status: 'summarized',
    ),
    advisorDecision: null,
    ingredients: const [],
    plannedSnapshot: null,
    consumedSnapshot: null,
    statusHistory: const [],
    lowTreatments: [
      MealLowTreatmentDetailsData(
        meal: mealRecord(
          id: 2,
          name: 'Dosłodzenie',
          plannedAt: treatmentTime,
          purpose: 'lowTreatment',
          status: 'confirmed',
        ),
        context: LowTreatmentContext(
          mealId: 2,
          relatedMealId: 1,
          source: LowTreatmentContextSource.dashboardAction,
          suggestedCarbs: 12,
          suggestedWithinMinutes: 15,
          reason: LowTreatmentReason.lowGlucose,
        ),
        ingredients: [
          mealIngredient(
            ingredientName: 'Glukoza',
            consumedTotalGrams: 10,
            carbsPer100g: 100,
          ),
        ],
      ),
    ],
  );
}

MealRecordData mealRecord({
  required int id,
  required String name,
  required DateTime plannedAt,
  required String status,
  String purpose = 'meal',
}) {
  return MealRecordData(
    id: id,
    name: name,
    purpose: purpose,
    status: status,
    plannedAt: plannedAt,
    summarizedAt: status == 'summarized' ? plannedAt : null,
    mealTemplateId: null,
    basedOnMealId: null,
    notes: null,
    createdAt: plannedAt,
    updatedAt: plannedAt,
    isSynced: false,
  );
}

MealIngredientDetailsData mealIngredient({
  required String ingredientName,
  required double consumedTotalGrams,
  required double carbsPer100g,
}) {
  final nutrition = IngredientNutritionData(
    carbsPer100g: carbsPer100g,
    fatPer100g: 0,
    fiberPer100g: 0,
    proteinPer100g: 0,
    carbsLabelMode: CarbsLabelMode.eu,
    nutritionConfidence: 1,
    effectiveAt: null,
  );

  return MealIngredientDetailsData(
    mealIngredientId: 1,
    ingredientId: 1,
    ingredientName: ingredientName,
    entryType: 'planned',
    portionLabel: '1g',
    plannedAmount: consumedTotalGrams,
    consumedAmount: consumedTotalGrams,
    quantityConfidence: 1,
    consumedConfidence: 1,
    plannedTotalGrams: consumedTotalGrams,
    consumedTotalGrams: consumedTotalGrams,
    prepMethod: null,
    notes: null,
    createdAt: DateTime(2026, 5, 24, 12),
    updatedAt: DateTime(2026, 5, 24, 12),
    currentNutrition: nutrition,
    plannedNutrition: nutrition,
    consumedNutrition: nutrition,
    plannedNutritionDiffersFromCurrent: false,
    consumedNutritionDiffersFromCurrent: false,
    historicalNutritionUnavailable: false,
  );
}
