import 'package:diabeatthis/common/family_sync/presentation/models/family_meal_details.dart';
import 'package:diabeatthis/common/presentation/details/meal_preview_controller.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page_body.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_macros.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_preview_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'family_collection_fixtures.dart';

void main() {
  testWidgets('recorded consumption renders in the shared meal macro widgets', (
    tester,
  ) async {
    final consumed = familySnapshotFixture();
    (consumed['payload'] as Map).addAll(<String, dynamic>{
      'snapshot_type': 'consumed',
      'total_grams': 40.0,
      'total_carbs_g': 4.0,
      'total_fiber_g': .8,
      'total_net_carbs_g': 3.2,
      'total_fat_g': .4,
      'total_protein_g': .8,
      'total_calories_kcal': 19.6,
    });
    final rows = familyCollectionFixtures(status: 'eaten')..add(consumed);
    final state = FamilyMealDetails(rows).build(2, 'portion')!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(
            (_) => throw StateError('Caregiver accessed patient database'),
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: MealPageBody.controlled(
              controller: CaregiverMealPreviewController(state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MealPortionMacros), findsOneWidget);
    expect(state.details.plannedSnapshot, isNull);
    expect(state.details.consumedSnapshot!.totalNetCarbsG, 3.2);
    expect(state.details.consumedSnapshot!.totalGrams, 40);
    expect(state.details.ingredients.single.plannedTotalGrams, 50);
    expect(find.byType(MealPreviewActions), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final status in ['planned', 'eaten']) {
    testWidgets(
      'shared caregiver meal opens ingredient through family callback: $status',
      (tester) async {
        final state = FamilyMealDetails(
          familyCollectionFixtures(status: status),
        ).build(2, 'portion')!;
        int? opened;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(
                (_) => throw StateError('Caregiver accessed patient database'),
              ),
            ],
            child: localizedMaterialApp(
              home: Scaffold(
                body: MealPageBody.controlled(
                  controller: CaregiverMealPreviewController(
                    state,
                    onOpenIngredient: (id) => opened = id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ingredient = find.byType(MealPortionIngredient);
        final tile = tester.widget<ListTile>(
          find.descendant(of: ingredient, matching: find.byType(ListTile)),
        );
        expect(tile.onTap, isNotNull);
        // Use the same tile callback even when the portion tab is not selected yet.
        tile.onTap!();
        expect(opened, state.details.ingredients.single.ingredientId);
        expect(find.byType(MealPreviewActions), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
