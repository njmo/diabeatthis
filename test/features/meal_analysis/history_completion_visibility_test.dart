import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../meals/presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment;
import 'build_before_meal_context_use_case_test.dart' show cutoff, reading;

void main() {
  test('completion is available only for incomplete local history', () {
    final details = mealDetailsWithLowTreatment();
    final full = MealAnalysisData(
      chartStart: cutoff,
      chartEnd: cutoff.add(const Duration(minutes: 10)),
      expectedChartEnd: cutoff.add(const Duration(minutes: 10)),
      eventStart: cutoff,
      eventEnd: cutoff,
      mealTime: cutoff,
      glucoseReadings: [reading(0), reading(5)],
      treatments: [],
      temporaryTargets: [],
      deviceStatuses: [],
      linkedActivities: [],
      linkedMeals: [],
      timelineEvents: [],
    );
    expect(
      MealPageState(
        details: details,
        analysis: full,
        usesLocalHistory: true,
      ).showHistoryDownload,
      true,
    );
    expect(
      MealPageState(
        details: details,
        usesLocalHistory: true,
      ).showHistoryDownload,
      true,
    );
    expect(
      MealPageState(
        details: details,
        usesLocalHistory: false,
      ).showHistoryDownload,
      false,
    );
    expect(
      MealPageState(
        details: details,
        analysis: full,
        usesLocalHistory: true,
        isDownloadingHistory: true,
      ).showHistoryDownload,
      true,
    );
  });
}
