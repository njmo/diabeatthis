import 'package:diabeatthis/common/family_sync/presentation/models/family_activity_log_details.dart';
import 'package:diabeatthis/common/family_sync/presentation/models/family_meal_details.dart';
import 'package:diabeatthis/common/history/nightscout_history_repositories.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/load_activity_log_analysis_use_case.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/analyze_meal_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../presentation/family_collection_fixtures.dart';
import 'nightscout_statistics_fixture.dart';

void main() {
  for (final empty in [false, true]) {
    test('caregiver statistics use only Nightscout; empty=$empty', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Patient database must not be accessed'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ns = StatisticsNightscout(empty: empty);
      final history = NightscoutHistoryRepositories(ns);
      final rows = familyCollectionFixtures(status: 'eaten');
      final details = FamilyMealDetails(rows).build(2, 'portion')!.details;
      final meal = await container
          .read(analyzeMealUseCaseProvider)
          .call(details, history: history, includeLocalContext: false);
      expect(meal, isNotNull);
      expect(meal!.glucoseStats.averageGlucose, empty ? isNull : 120);
      expect(meal.linkedMeals, isEmpty);
      expect(meal.linkedActivities, isEmpty);
      expect(meal.lowTreatments, isEmpty);
      expect(meal.hasContinuousGlucoseHistory, !empty);
      expect(
        ns.glucoseWindows.single.$1,
        details.analysisTime.subtract(const Duration(minutes: 45)),
      );
      expect(
        ns.glucoseWindows.single.$2,
        details.analysisTime.add(details.observationWindow),
      );
      final log = familyActivityLogDetails(rows, 6)!.data;
      final activity = await container
          .read(loadActivityLogAnalysisUseCaseProvider)
          .call(
            log,
            history: history,
            includeContext: true,
            includeLocalContext: false,
          );
      expect(activity!.averageGlucoseDuringActivity, empty ? isNull : 120);
      expect(activity.lastMeal, isNull);
      expect(activity.postActivityMeals, isEmpty);
      expect(
        ns.glucoseWindows.last.$2,
        log.endedAt!.add(const Duration(hours: 3)),
      );
      expect(ns.deviceWindows.length, 2);
      expect(ns.treatmentWindows.length, 2);
    });
  }
}
