import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:diabeatthis/common/widgets/timeline_selection_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_charts_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_outcome_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_timeline_event_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_low_treatments_display_test.dart' show mealDetailsWithLowTreatment;

void main() {
  for (final width in [320.0, 390.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('review fits width $width and text scale $textScale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealDetailsControllerProvider(
                1,
              ).overrideWith(() => ReviewTestController()),
            ],
            child: localizedMaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: const MealPage(mealId: 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(MealOutcomeSection), findsOneWidget);
        expect(find.text('Czas do szczytu'), findsOneWidget);
        expect(find.text('Początek szybkiego wzrostu'), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
        final basicChart = tester.widget<TimelineAnalysisCharts>(
          find.byType(TimelineAnalysisCharts),
        );
        expect(
          basicChart.events.any((event) => event.label == 'Korekta ręczna'),
          isTrue,
        );
        expect(find.text('Ręcznie · rodzic / opiekun'), findsOneWidget);
        expect(find.text('Pozostałe korekty'), findsOneWidget);
        expect(find.text('O 5 min krócej niż proponowano'), findsOneWidget);
        final eating = basicChart.ranges.singleWhere(
          (range) => range.label == 'Jedzenie posiłku',
        );
        expect(
          eating.end.difference(eating.start),
          const Duration(minutes: 20),
        );
        expect(find.byType(MealTimelineEventTile), findsNothing);
        await tester.tap(find.text('Zaawansowany'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(MealChartsSection));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final chart = tester.widget<TimelineAnalysisCharts>(
          find.byType(TimelineAnalysisCharts),
        );
        expect(chart.fitToWidth, isTrue);
        expect(chart.showDeviceMetrics, isFalse);
      });
    }
  }

  testWidgets('tapping an event selects its time and returns to the chart', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        mealDetailsControllerProvider(
          1,
        ).overrideWith(() => ReviewTestController()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(home: const MealPage(mealId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zaawansowany'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(MealTimelineEventTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MealTimelineEventTile));
    await tester.pumpAndSettle();
    expect(
      container.read(mealDetailsControllerProvider(1)).value?.selectedTimestamp,
      DateTime(2026, 5, 24, 11, 45),
    );
    expect(
      tester.getTopLeft(find.byType(MealChartsSection)).dy,
      greaterThanOrEqualTo(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chart selection updates recorded-time details without inventing missing IOB',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          mealDetailsControllerProvider(
            1,
          ).overrideWith(() => ReviewTestController()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(home: const MealPage(mealId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zaawansowany'));
      await tester.pumpAndSettle();
      final chart = tester.widget<TimelineAnalysisCharts>(
        find.byType(TimelineAnalysisCharts),
      );
      chart.onTimestampSelected!(DateTime(2026, 5, 24, 13, 15));
      await tester.pumpAndSettle();
      final summary = tester.widget<TimelineSelectionSummary>(
        find.byType(TimelineSelectionSummary),
      );
      expect(summary.timestamp, DateTime(2026, 5, 24, 13, 15));
      expect(summary.deviceStatuses, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class ReviewTestController extends MealDetailsControllerNotifier {
  @override
  Future<MealPageState> build(int mealId) async {
    final details = mealDetailsWithLowTreatment();
    final start = details.meal.analysisTime;
    return MealPageState(
      details: details.copyWith(
        statusHistory: [
          MealStatusHistoryEntryData(
            id: 1,
            mealId: mealId,
            status: 'bolused-waiting',
            createdAt: start.subtract(const Duration(minutes: 15)),
          ),
          MealStatusHistoryEntryData(
            id: 2,
            mealId: mealId,
            status: 'waited-eating',
            createdAt: start,
          ),
          MealStatusHistoryEntryData(
            id: 3,
            mealId: mealId,
            status: 'eaten',
            createdAt: start.add(const Duration(minutes: 20)),
          ),
        ],
        advisorDecision: MealAdvisorDecisionData(
          result: 'bolusWaitThenEat',
          initialWaitTime: 20,
          finalWaitTime: 99,
          waitTimeIgnored: false,
          extendedCarbsGrams: 0,
          extendedCarbsDeliveryMode: null,
          extendedCarbsDelayMinutes: null,
          extendedCarbsDurationMinutes: null,
          decisionReason: null,
          version: 1,
          isSynced: true,
          createdAt: start,
          updatedAt: start,
        ),
      ),
      analysis: MealAnalysisData(
        chartStart: start.subtract(const Duration(minutes: 45)),
        chartEnd: start.add(const Duration(hours: 6)),
        expectedChartEnd: start.add(const Duration(hours: 6)),
        eventStart: start.subtract(const Duration(hours: 1)),
        eventEnd: start.add(const Duration(hours: 6)),
        mealTime: start,
        glucoseReadings: [
          for (var minute = -45; minute <= 360; minute += 5)
            Glucose(
              externalId: '$minute',
              source: GlucoseSource.cloud,
              date: start.add(Duration(minutes: minute)),
              sgv: minute < 0
                  ? 112
                  : minute < 90
                  ? 112 + minute
                  : minute < 180
                  ? 202 - (minute - 90)
                  : 112,
              direction: 'Flat',
            ),
        ],
        treatments: const [],
        temporaryTargets: const [],
        deviceStatuses: const [],
        linkedActivities: const [],
        linkedMeals: const [],
        timelineEvents: [
          MealTimelineEventData(
            timestamp: start.subtract(const Duration(minutes: 15)),
            type: MealTimelineEventType.manualCorrection,
            label: 'Bolus',
            value: '5.2 j.',
          ),
        ],
      ),
    );
  }
}
