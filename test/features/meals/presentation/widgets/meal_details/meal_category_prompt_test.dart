import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_preview_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_low_treatments_display_test.dart' show mealDetailsWithLowTreatment;

void main() {
  for (final category in [null, 'breakfast', 'invalid']) {
    testWidgets('category prompt reflects stored category $category', (
      tester,
    ) async {
      final details = mealDetailsWithLowTreatment();
      final meal = details.meal;
      final updated = details.copyWith(
        meal: MealRecordData(
          id: meal.id,
          name: meal.name,
          category: category,
          status: meal.status,
          plannedAt: meal.plannedAt,
          summarizedAt: meal.summarizedAt,
          mealTemplateId: meal.mealTemplateId,
          basedOnMealId: meal.basedOnMealId,
          notes: meal.notes,
          createdAt: meal.createdAt,
          updatedAt: meal.updatedAt,
          isSynced: meal.isSynced,
        ),
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MealPreviewHeader(state: MealPageState(details: updated)),
          ),
        ),
      );
      expect(
        find.text('Przypisz rodzaj posiłku'),
        category == 'breakfast' ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
