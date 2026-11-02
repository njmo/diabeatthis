import 'package:diabeatthis/common/widgets/analysis_mode_selector.dart';
import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_charts_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_outcome_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../../helpers/localized_material_app.dart';
import 'meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment, mealRecord;

void main() {
  final start = DateTime(2026, 11, 2, 12);
  MealPageState state(String status, {bool? complete}) {
    final details = mealDetailsWithLowTreatment().copyWith(
      meal: mealRecord(
        id: 1,
        name: 'Preview',
        plannedAt: start,
        status: status,
      ),
      lowTreatments: [],
    );
    return MealPageState(
      details: details,
      analysis: complete == null
          ? null
          : MealAnalysisData(
              chartStart: start,
              chartEnd: start.add(Duration(minutes: complete ? 90 : 20)),
              expectedChartEnd: start.add(const Duration(minutes: 90)),
              eventStart: start,
              eventEnd: start.add(const Duration(minutes: 90)),
              mealTime: start,
              glucoseReadings: [],
              treatments: [],
              temporaryTargets: [],
              deviceStatuses: [],
              linkedActivities: [],
              linkedMeals: [],
              timelineEvents: [],
            ),
    );
  }

  Future<void> show(WidgetTester tester, MealPageState state) async {
    await tester.pumpWidget(
      ProviderScope(
        child: localizedMaterialApp(
          home: Scaffold(body: MealPageBody(state: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final status in ['planned', 'skipped', 'interrupted', 'eating']) {
    testWidgets('$status does not show outcome chapters or mode selection', (
      tester,
    ) async {
      await show(tester, state(status));
      expect(find.byType(MealOutcomeSection), findsNothing);
      expect(find.byType(MealChartsSection), findsNothing);
      expect(find.byType(AnalysisModeSelector), findsNothing);
      expect(find.text('Co zostało zjedzone'), findsNothing);
      expect(
        tester.widget<SwipeableCards>(find.byType(SwipeableCards)).labels,
        contains('Działanie aplikacji'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ongoing observation reveals only the partial chart on request', (
    tester,
  ) async {
    await show(tester, state('summarized', complete: false));
    expect(find.text('Obserwacja trwa · do 13:30'), findsOneWidget);
    expect(find.byType(MealOutcomeSection), findsNothing);
    expect(find.byType(MealChartsSection), findsNothing);
    await tester.tap(find.text('Pokaż dotychczasowy przebieg'));
    await tester.pumpAndSettle();
    expect(find.byType(MealChartsSection), findsOneWidget);
    expect(find.byType(MealOutcomeSection), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'elapsed observation with missing data is not presented as complete data',
    (tester) async {
      await show(tester, state('summarized', complete: true));
      expect(
        find.text('Okres obserwacji zakończony · dane niepełne'),
        findsOneWidget,
      );
      expect(find.byType(MealOutcomeSection), findsOneWidget);
      expect(
        tester.widget<SwipeableCards>(find.byType(SwipeableCards)).labels,
        hasLength(6),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('progressive review fits width $width with enlarged text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: localizedMaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: MealPageBody(state: state('summarized', complete: true)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MealOutcomeSection), findsOneWidget);
      expect(find.byType(AnalysisModeSelector), findsNothing);
    });
  }
}
