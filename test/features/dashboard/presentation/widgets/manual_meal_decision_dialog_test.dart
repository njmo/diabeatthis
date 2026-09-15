import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'prefills advice and requires positive wait before returning a choice',
    (tester) async {
      ManualMealDecision? result;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<ManualMealDecision>(
                    context: context,
                    builder: (_) => const ManualMealDecisionDialog(
                      initialValue: ManualMealDecision(
                        decision: MealDecision.bolusWaitThenEat,
                        waitMinutes: 15,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(find.text('Podaj dodatnią liczbę minut.'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(find.byType(TextFormField), '8');
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(result!.waitMinutes, 8);
      expect(result!.decision, MealDecision.bolusWaitThenEat);
      expect(tester.takeException(), isNull);
    },
  );
}
