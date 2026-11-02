import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_history_facts.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/prior_meal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/localized_material_app.dart';
import 'build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros;

void main() {
  testWidgets('shows only the nearest strictly preceding meal', (tester) async {
    final data = await builder(
      meals: [
        RecordedMealContext(
          mealId: 2,
          name: 'Breakfast',
          eatenAt: cutoff.subtract(const Duration(hours: 2)),
          snapshot: null,
        ),
        RecordedMealContext(
          mealId: 1,
          name: 'Dinner',
          eatenAt: cutoff.subtract(const Duration(hours: 16)),
          snapshot: null,
        ),
        RecordedMealContext(
          mealId: 3,
          name: 'Current',
          eatenAt: cutoff,
          snapshot: null,
        ),
      ],
    )(asOf: cutoff, macros: macros);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BeforeMealHistoryFacts(data: data, precedingMealOnly: true),
          ),
        ),
      ),
    );
    expect(find.byType(PriorMealCard), findsOneWidget);
    expect(find.textContaining('Breakfast ·'), findsOneWidget);
    expect(find.textContaining('Dinner ·'), findsNothing);
    expect(find.text('Poprzedzający posiłek'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
