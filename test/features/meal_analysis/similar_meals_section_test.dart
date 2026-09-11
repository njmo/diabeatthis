import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meals/data/providers/similar_meal_glucose_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/similar_meals_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meal_tile.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meals_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../meals/presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment;
import 'build_meal_outcome_context_use_case_test.dart' show outcome;
import 'find_similar_meals_use_case_test.dart'
    show candidate, referenceTime, targetMacros;
import 'meal_glucose_test_helpers.dart';

void main() {
  testWidgets('selecting a match opens it without expanding an analysis', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SimilarMealTile(
            match: SimilarMealMatch(meal: candidate(1), distance: 0),
            onTap: () => opened = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Meal 1'));
    await tester.pumpAndSettle();
    expect(opened, true);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('missing target snapshot needs no history repository', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      await container.read(
        similarMealsProvider(mealDetailsWithLowTreatment()).future,
      ),
      isNull,
    );
  });

  testWidgets(
    'lazy search retries and displays saved macros without nested analyses',
    (tester) async {
      final details = mealDetailsWithLowTreatment();
      var calls = 0;
      var outcomeCalls = 0;
      tester.view.physicalSize = const Size(320, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            similarMealGlucoseProvider((
              mealId: 1,
              asOf: referenceTime,
            )).overrideWith((ref) async {
              outcomeCalls++;
              return glucosePreview(outcome());
            }),
            similarMealsProvider(details).overrideWith((ref) async {
              calls++;
              if (calls == 1) throw StateError('offline');
              return SimilarMealContext(
                asOf: referenceTime,
                searchStart: referenceTime.subtract(const Duration(days: 90)),
                target: targetMacros,
                matches: [SimilarMealMatch(meal: candidate(1), distance: 0)],
              );
            }),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SimilarMealsSection(details: details),
              ),
            ),
          ),
        ),
      );
      expect(calls, 0);
      expect(outcomeCalls, 0);
      await tester.tap(find.text('Podobne posiłki'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(outcomeCalls, 1);
      expect(find.text('Brak: 100%'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.text('Meal 1'), findsOneWidget);
      expect(find.text('WW netto 30 g'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
