import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meals_overview.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('meal energy chart keeps low-treatment carbohydrates separate', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: DayMealsOverview(
            mealCount: 3,
            netCarbs: 30,
            protein: 20,
            fat: 10,
            lowCount: 2,
            lowCarbs: 15,
          ),
        ),
      ),
    );
    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections.map((section) => section.value), [120, 80, 90]);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('15,0 g'), findsOneWidget);
    expect(find.textContaining('30,0 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing macros do not draw a misleading composition', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: DayMealsOverview(
            mealCount: 1,
            netCarbs: null,
            protein: null,
            fat: null,
            lowCount: null,
            lowCarbs: null,
          ),
        ),
      ),
    );
    expect(
      tester.widget<PieChart>(find.byType(PieChart)).data.sections,
      hasLength(1),
    );
    expect(find.textContaining('—'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow display and large text retain readable stats without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        localizedMaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DayMealsOverview(
                    mealCount: 4,
                    netCarbs: 180,
                    protein: 70,
                    fat: 55,
                    lowCount: 3,
                    lowCarbs: 25,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('180,0 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
