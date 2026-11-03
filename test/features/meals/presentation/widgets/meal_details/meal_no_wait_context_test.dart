import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_application_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_review_test.dart' show ReviewTestController;

void main() {
  testWidgets(
    'immediate eating has no wait comparison, wait metadata or navigation arrows',
    (tester) async {
      final state = await ReviewTestController().build(1);
      final at = state.details.meal.plannedAt;
      final decision = MealAdvisorDecisionData(
        result: 'eatNow',
        initialWaitTime: 0,
        finalWaitTime: 0,
        waitTimeIgnored: false,
        extendedCarbsGrams: 0,
        extendedCarbsDeliveryMode: null,
        extendedCarbsDelayMinutes: null,
        extendedCarbsDurationMinutes: null,
        decisionReason: 'immediateMeal',
        version: 1,
        isSynced: true,
        createdAt: at,
        updatedAt: at,
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealApplicationContext(
                state: state.copyWith(
                  details: state.details.copyWith(advisorDecision: decision),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Czekanie'), findsNothing);
      expect(find.textContaining('0 min'), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Zapis i synchronizacja'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
