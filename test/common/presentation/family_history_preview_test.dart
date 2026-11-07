import 'package:diabeatthis/common/family_sync/presentation/models/family_activity_log_details.dart';
import 'package:diabeatthis/common/family_sync/presentation/models/family_meal_details.dart';
import 'package:diabeatthis/common/presentation/details/activity_log_preview_controller.dart';
import 'package:diabeatthis/common/presentation/details/meal_preview_controller.dart';
import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_body.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_information.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page_body.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_category_edit_button.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_preview_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'family_collection_fixtures.dart';

void main() {
  test(
    'family meal resolves saved nutrition before edit and preserves valid legacy snapshots',
    () {
      final rows = familyCollectionFixtures(status: 'eaten')
        ..add(familySnapshotFixture());
      final state = FamilyMealDetails(rows).build(2, 'portion')!;
      final item = state.details.ingredients.single;
      expect(item.currentNutrition.carbsPer100g, 15);
      expect(item.plannedNutrition.carbsPer100g, 10);
      expect(item.plannedHistoricalNutritionUnavailable, isFalse);
      expect(item.plannedTotalGrams, 50);
      expect(item.consumedTotalGrams, 40);
      expect(state.details.plannedSnapshot!.totalNetCarbsG, 4);
      expect(state.details.consumedSnapshot, isNull);
      final snapshot = rows.last['payload'] as Map;
      snapshot['updated_at'] = familyRecordTime + 1;
      expect(
        FamilyMealDetails(rows)
            .build(2, 'portion')!
            .details
            .ingredients
            .single
            .plannedHistoricalNutritionUnavailable,
        isTrue,
      );
    },
  );

  test(
    'family preview never invents missing dependencies or historical portion weights',
    () {
      final rows = familyCollectionFixtures();
      expect(
        FamilyMealDetails(
          rows,
        ).build(2, 'portion')!.details.plannedPreviewNutrition,
        isNull,
      );
      (rows[2]['payload'] as Map)['grams_per_portion_used'] = null;
      (rows[2]['payload'] as Map)['portion_id'] = 999;
      final state = FamilyMealDetails(rows).build(2, 'portion')!;
      expect(state.details.ingredients.single.recordedWeightAvailable, isFalse);
      expect(state.details.plannedPreviewNutrition, isNull);
      rows.removeAt(0);
      expect(FamilyMealDetails(rows).build(2, 'portion'), isNull);
    },
  );

  for (final status in ['planned', 'eaten']) {
    testWidgets(
      'same meal body renders $status family history without local actions or reads',
      (tester) async {
        final state = FamilyMealDetails(
          familyCollectionFixtures(status: status),
        ).build(2, 'portion')!;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(
                (_) =>
                    throw StateError('Caregiver accessed local patient data'),
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
        expect(find.byType(SwipeableCards), findsOneWidget);
        expect(find.text('Lunch'), findsOneWidget);
        expect(find.byType(MealCategoryEditButton), findsNothing);
        expect(find.byType(MealPreviewActions), findsNothing);
        expect(find.byType(MealPortionIngredient), findsOneWidget);
        final tile = tester.widget<ListTile>(
          find.descendant(
            of: find.byType(MealPortionIngredient),
            matching: find.byType(ListTile),
          ),
        );
        expect(tile.onTap, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reference counts stay portions and synthetic weight is hidden', (
    tester,
  ) async {
    final rows = familyCollectionFixtures()..add(familySnapshotFixture());
    (rows.first['payload'] as Map)['is_reference'] = 1;
    (rows[2]['payload'] as Map).addAll(<String, dynamic>{
      'amount': 2.0,
      'consumed_amount': 1.0,
      'grams_per_portion_used': 100.0,
    });
    final state = FamilyMealDetails(rows).build(2, 'portion')!;
    expect(state.details.ingredients.single.isReference, isTrue);
    expect(state.details.ingredients.single.plannedTotalGrams, 200);
    await tester.pumpWidget(
      ProviderScope(
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
    expect(find.textContaining('200 g'), findsNothing);
    expect(find.textContaining('100 g'), findsNothing);
    expect(find.textContaining('porcji referencyjnych'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same activity body omits unshared analytics and historic settings',
    (tester) async {
      final state = familyActivityLogDetails(familyCollectionFixtures(), 6)!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('Caregiver accessed local patient data'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: ActivityLogBody.controlled(
                controller: CaregiverActivityLogPreviewController(state),
                onTimestampSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SwipeableCards), findsOneWidget);
      expect(find.byType(ActivityLogInformation), findsOneWidget);
      expect(find.text('Swimming'), findsOneWidget);
      expect(find.text('Outside'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
