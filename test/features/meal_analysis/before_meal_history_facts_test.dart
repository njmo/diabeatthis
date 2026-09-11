import 'package:diabeatthis/core/domain/model/meal_snapshot.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_history_facts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros;

void main() {
  testWidgets(
    'renders planned, consumed and missing snapshots in prior meals',
    (tester) async {
      final meals = [
        for (final type in MealSnapshotType.values)
          RecordedMealContext(
            mealId: type.index + 1,
            name: type.name,
            eatenAt: cutoff.subtract(const Duration(hours: 2)),
            snapshot: MealSnapshot.initial(
              mealId: type.index + 1,
              snapshotType: type,
            ),
          ),
        RecordedMealContext(
          mealId: 3,
          name: 'Missing',
          eatenAt: cutoff.subtract(const Duration(hours: 1)),
          snapshot: null,
        ),
      ];
      final data = await builder(meals: meals)(asOf: cutoff, macros: macros);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeforeMealHistoryFacts(data: data),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('planned ·'), findsOneWidget);
      expect(find.textContaining('consumed ·'), findsOneWidget);
      expect(find.textContaining('Missing ·'), findsOneWidget);
      expect(find.textContaining('makro planowane'), findsOneWidget);
      expect(find.textContaining('makro spożyte'), findsOneWidget);
      expect(find.textContaining('brak ówczesnego makro'), findsOneWidget);
    },
  );
}
