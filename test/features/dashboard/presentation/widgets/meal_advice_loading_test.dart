import 'package:diabeatthis/common/widgets/manual_meal_decision_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_advice_loading.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../data/ai_assisted_meal_advisor_test.dart'
    show AssistedAdvisorFixture;

void main() {
  testWidgets(
    'manual form opens immediately during pending context and cancellation leaves manual choice available',
    (tester) async {
      final fixture = AssistedAdvisorFixture(assisted: true);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: localizedMaterialApp(
            home: const Scaffold(
              body: MealStatusDialog(
                meal: Meal(id: 1, name: 'Test meal', status: 'planned'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Zjem'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MealAdviceLoading), findsOneWidget);
      expect(find.text('Przygotowuję kontekst posiłku…'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(find.byType(ManualMealDecisionDialog), findsOneWidget);
      expect(fixture.state.isPreparingAdvice, isFalse);
      expect(find.byType(MealAdviceLoading), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(ManualMealDecisionDialog),
          matching: find.text('Anuluj'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ManualMealDecisionDialog), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      fixture.gate.complete();
      await tester.pumpAndSettle();
      expect(fixture.state.beforeMealContext, isNull);
      expect(fixture.state.advice.decision, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cancelling a manual form opened after a completed suggestion preserves that suggestion',
    (tester) async {
      final fixture = AssistedAdvisorFixture(assisted: false);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: localizedMaterialApp(
            home: const Scaffold(
              body: MealStatusDialog(
                meal: Meal(id: 1, name: 'Test meal', status: 'planned'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Zjem'));
      await tester.pumpAndSettle();
      final original = fixture.state.advice;
      expect(original.decision, isNotNull);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ManualMealDecisionDialog),
          matching: find.text('Anuluj'),
        ),
      );
      await tester.pumpAndSettle();
      expect(fixture.state.advice, same(original));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
