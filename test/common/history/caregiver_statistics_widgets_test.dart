import 'package:diabeatthis/common/family_sync/presentation/models/family_activity_log_details.dart';
import 'package:diabeatthis/common/family_sync/presentation/models/family_meal_details.dart';
import 'package:diabeatthis/common/history/nightscout_history_repositories.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/details/meal_preview_controller.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/load_activity_log_analysis_use_case.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_after_section.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_before_section.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/meal_outcome_facts.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/analyze_meal_use_case.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page_body.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_charts_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_low_treatments_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_preview_actions.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meals_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../presentation/family_collection_fixtures.dart';
import 'nightscout_statistics_fixture.dart';

void main() {
  testWidgets(
    'Nightscout meal chart selection stays local to the read-only view',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('No patient DB'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final state = FamilyMealDetails(
        familyCollectionFixtures(status: 'eaten'),
      ).build(2, 'portion')!;
      final details = state.details;
      final data = await container
          .read(analyzeMealUseCaseProvider)
          .call(
            details,
            history: NightscoutHistoryRepositories(StatisticsNightscout()),
            includeLocalContext: false,
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MealPageBody.controlled(
                controller: CaregiverMealPreviewController(
                  state.copyWith(analysis: data!),
                  showAnalysis: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byType(MealPreviewActions, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(MealLowTreatmentsSection, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(SimilarMealsSection, skipOffstage: false),
        findsNothing,
      );
      final selected = details.analysisTime.add(const Duration(minutes: 10));
      tester
          .widget<MealChartsSection>(find.byType(MealChartsSection))
          .onTimestampSelected!(selected);
      await tester.pump();
      expect(
        tester
            .widget<MealChartsSection>(find.byType(MealChartsSection))
            .selectedTimestamp,
        selected,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing Nightscout history does not assert absence of child meals or low glucose',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('No patient DB'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final log = familyActivityLogDetails(familyCollectionFixtures(), 6)!.data;
      final data = await container
          .read(loadActivityLogAnalysisUseCaseProvider)
          .call(
            log,
            history: NightscoutHistoryRepositories(
              StatisticsNightscout(empty: true),
            ),
            includeContext: true,
            includeLocalContext: false,
          );
      late BuildContext viewContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                viewContext = context;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ActivityBeforeSection(
                        analysis: data!,
                        log: log,
                        showRecordedSettings: false,
                      ),
                      ActivityAfterSection(
                        analysis: data,
                        hasLocalMealContext: false,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(
        find.text(viewContext.lang.activityNoAfterMealRecords),
        findsNothing,
      );
      expect(
        find.textContaining(viewContext.lang.activityNoLowRecorded),
        findsNothing,
      );
      expect(
        find.text(viewContext.lang.activityRecordedSettings),
        findsNothing,
      );
      expect(find.text(viewContext.lang.activityNoMealWindow), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unshared meal context remains absent from shared preview', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError('No patient DB'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final state = FamilyMealDetails(
      familyCollectionFixtures(status: 'eaten'),
    ).build(2, 'portion')!;
    final data = await container
        .read(analyzeMealUseCaseProvider)
        .call(
          state.details,
          history: NightscoutHistoryRepositories(StatisticsNightscout()),
          includeLocalContext: false,
        );
    expect(data!.lowTreatments, isEmpty);
    expect(data.linkedActivities, isEmpty);
    expect(data.linkedMeals, isEmpty);
    expect(data.outcomeContext!.subsequentMeals, isNull);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MealPageBody.controlled(
              controller: CaregiverMealPreviewController(
                state.copyWith(analysis: data),
                showAnalysis: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(MealLowTreatmentsSection, skipOffstage: false),
      findsNothing,
    );
    expect(find.byType(SimilarMealsSection, skipOffstage: false), findsNothing);
    expect(find.byType(MealPreviewActions, skipOffstage: false), findsNothing);
    expect(find.byType(MealOutcomeFacts, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
