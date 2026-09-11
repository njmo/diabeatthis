import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_context_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_meal_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_review_entry.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  testWidgets(
    'today shows pending entries inline without opening another page',
    (tester) async {
      final date = DateTime(2026, 9, 11, 12);
      final day = await BuildDayContextUseCase(
        now: () => date,
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      )();
      final wizard = BolusWizard(
        nightscoutObjectId: 'id',
        remoteSource: 'https://example.com',
        createdAt: date,
        date: date,
        glucose: 120,
        units: null,
        notes: null,
        calculatorResult: null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayContextProvider.overrideWith((ref) async => day),
            dayMealReviewProvider(day.start).overrideWith(
              (ref) async => [
                DayMealReviewEntry(
                  meal: null,
                  wizards: [wizard],
                  assignments: [],
                ),
              ],
            ),
          ],
          child: localizedMaterialApp(home: const Scaffold(body: TodayPage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Wpis kalkulatora do sprawdzenia'),
        250,
      );
      await tester.pumpAndSettle();
      expect(find.text('1 do sprawdzenia'), findsOneWidget);
      expect(find.text('Przejrzyj i uzupełnij posiłki'), findsNothing);
      expect(find.byTooltip('Dodaj posiłek wstecz'), findsOneWidget);
      await tester.tap(find.text('Wpis kalkulatora do sprawdzenia'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Dodaj posiłek wstecz'), findsOneWidget);
      expect(find.byTooltip('Połącz z posiłkiem'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
