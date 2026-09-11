import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../meals/presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment;

void main() {
  final start = DateTime(2026, 9, 9, 20);
  MealPageState state(List<int> seconds, {bool fetched = false}) =>
      MealPageState(
        details: mealDetailsWithLowTreatment(),
        usesLocalHistory: true,
        hasFetchedCloudHistory: fetched,
        analysis: MealAnalysisData(
          chartStart: start,
          chartEnd: start.add(const Duration(minutes: 20)),
          expectedChartEnd: start.add(const Duration(minutes: 20)),
          eventStart: start,
          eventEnd: start,
          mealTime: start,
          glucoseReadings: [
            for (final s in seconds)
              Glucose(
                externalId: null,
                source: GlucoseSource.cloud,
                date: start.add(Duration(seconds: s)),
                sgv: 120,
                direction: 'Flat',
              ),
          ],
          deviceStatuses: [],
          treatments: [],
          temporaryTargets: [],
          linkedActivities: [],
          linkedMeals: [],
          timelineEvents: [],
        ),
      );
  test(
    'clustered readings do not hide missing history even after an attempted cloud fetch',
    () {
      expect(state([0, 60, 120, 180]).showHistoryDownload, isTrue);
      expect(
        state([0, 60, 120, 180], fetched: true).showHistoryDownload,
        isTrue,
      );
    },
  );
  test('complete glucose with unknown AAPS history offers download once', () {
    expect(state([0, 301, 602, 903]).showHistoryDownload, isTrue);
    final checked = state([0, 301, 602, 903], fetched: true);
    expect(checked.showHistoryDownload, isFalse);
    expect(
      checked.copyWith(selectedTimestamp: start).showHistoryDownload,
      isFalse,
    );
  });
}
