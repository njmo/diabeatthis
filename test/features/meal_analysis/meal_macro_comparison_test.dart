import 'package:diabeatthis/features/meals/common/widgets/meal_macro_comparison.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('ratio uses energy rather than mass and fits large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const SingleChildScrollView(
              child: MealMacroComparison(
                netCarbs: 9,
                protein: 9,
                fat: 8,
                showRatio: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('WW netto 9 g'), findsOneWidget);
    expect(find.text('Udział energii WW/B/T: 25% / 25% / 50%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('zero macros do not produce invented percentages', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: const MealMacroComparison(
            netCarbs: 0,
            protein: 0,
            fat: 0,
            showRatio: true,
          ),
        ),
      ),
    );
    expect(find.textContaining('Udział energii'), findsNothing);
    expect(find.text('WW netto 0 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
