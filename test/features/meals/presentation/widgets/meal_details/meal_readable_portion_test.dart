import 'package:diabeatthis/common/widgets/plan_actual_meter.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_macros.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../../helpers/localized_material_app.dart';
import 'meal_cards_test.dart' show cardSnapshot;
import 'meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment, mealIngredient;

void main() {
  for (final consumed in [20.0, 30.0, 0.0]) {
    testWidgets(
      'portion $consumed shows ingredients first and compares only changes',
      (tester) async {
        final details = mealDetailsWithLowTreatment().copyWith(
          ingredients: [
            mealIngredient(
              ingredientName: 'Potato',
              consumedTotalGrams: 100,
              carbsPer100g: 20,
            ),
          ],
          plannedSnapshot: cardSnapshot('planned', 20, 100),
          consumedSnapshot: cardSnapshot('consumed', consumed, 100),
        );
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MealPortionOverview(details: details),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MealPortionIngredient), findsOneWidget);
        expect(find.text('Potato').hitTestable(), findsOneWidget);
        expect(
          find.byType(PlanActualMeter),
          consumed == 20 ? findsNothing : findsOneWidget,
        );
        expect(find.byType(Slider), findsNothing);
        if (consumed == 20) {
          expect(find.byType(MealPortionMacros), findsOneWidget);
          expect(
            tester.getTopLeft(find.byType(MealPortionIngredient)).dy,
            lessThan(tester.getTopLeft(find.byType(MealPortionMacros)).dy),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
