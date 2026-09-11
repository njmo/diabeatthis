import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_mode_selector.dart';
import '../../common/widgets/meal_review_chapter.dart';
import '../../data/models/meal_start_context_data.dart';
import '../controllers/meal_details_controller.dart';
import '../models/meal_page_state.dart';
import '../widgets/meal_details/current_meal_macro_comparison.dart';
import '../widgets/meal_details/meal_activity_analysis_section.dart';
import '../widgets/meal_details/meal_advice_history_section.dart';
import '../widgets/meal_details/meal_advisor_result_section.dart';
import '../widgets/meal_details/meal_before_context_section.dart';
import '../widgets/meal_details/meal_charts_section.dart';
import '../widgets/meal_details/meal_comparison_section.dart';
import '../widgets/meal_details/meal_header.dart';
import '../widgets/meal_details/meal_history_download_button.dart';
import '../widgets/meal_details/meal_low_treatments_section.dart';
import '../widgets/meal_details/meal_nutrition_analysis_section.dart';
import '../widgets/meal_details/meal_observation_context.dart';
import '../widgets/meal_details/meal_outcome_section.dart';
import '../widgets/meal_details/meal_review_findings.dart';
import '../widgets/meal_details/meal_snapshots_section.dart';
import '../widgets/meal_details/meal_start_context_section.dart';
import '../widgets/meal_details/meal_technical_section.dart';
import '../widgets/meal_details/similar_meals_section.dart';

@RoutePage()
class MealPage extends ConsumerWidget {
  final int mealId;

  const MealPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealDetailsControllerProvider(mealId));

    return Scaffold(
      appBar: AppBar(title: Text(context.lang.mealReviewPageTitle)),
      floatingActionButton: state.maybeWhen(
        data: (value) => value.showHistoryDownload
            ? MealHistoryDownloadButton(state: value)
            : null,
        orElse: () => null,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.lang.mealLoadError(error))),
        data: (value) => MealPageBody(state: value),
      ),
    );
  }
}

class MealPageBody extends HookConsumerWidget {
  final MealPageState state;

  const MealPageBody({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartKey = useMemoized(() => GlobalKey());
    final advanced = useState(false);
    final details = state.details;
    final chart = MealChartsSection(
      key: chartKey,
      details: details,
      analysis: state.analysis,
      analysisError: state.analysisError,
      selectedTimestamp: state.selectedTimestamp,
      advanced: advanced.value,
    );
    final bottomPadding =
        (state.showHistoryDownload ? 96 : 16) +
        MediaQuery.viewPaddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnalysisModeSelector(
            advanced: advanced.value,
            basicLabel: context.lang.mealReviewBasicMode,
            advancedLabel: context.lang.mealReviewAdvancedMode,
            onChanged: (value) => advanced.value = value,
          ),
          const SizedBox(height: 16),
          MealHeader(state: state),
          const SizedBox(height: 12),
          if (details.meal.isEaten)
            MealReviewChapter(
              title: context.lang.mealGlucoseChapter,
              subtitle: context.lang.mealGlucoseChapterHint,
              icon: Icons.show_chart_rounded,
            ),
          if (details.meal.isEaten && state.analysis == null) chart,
          if (details.meal.isEaten && state.analysis != null)
            MealOutcomeSection(
              analysis: state.analysis!,
              advanced: advanced.value,
              chart: chart,
            ),

          if (details.meal.isEaten)
            MealReviewChapter(
              title: context.lang.mealContextChapter,
              subtitle: context.lang.mealContextChapterHint,
              icon: Icons.history_rounded,
            ),
          if (details.meal.isEaten)
            MealBeforeContextSection(
              key: ValueKey(details.meal.id),
              details: details,
            ),
          if (advanced.value && details.meal.isEaten && state.analysis != null)
            MealReviewFindings(analysis: state.analysis!, details: details),
          if (advanced.value && details.meal.isEaten && state.analysis != null)
            MealActivityAnalysisSection(
              mealId: details.meal.id,
              analysis: state.analysis!,
              selectedTimestamp: state.selectedTimestamp,
              onTimestampSelected: (timestamp) {
                ref
                    .read(
                      mealDetailsControllerProvider(details.meal.id).notifier,
                    )
                    .selectTimestamp(timestamp);
                final chartContext = chartKey.currentContext;
                if (chartContext != null) {
                  Scrollable.ensureVisible(
                    chartContext,
                    duration: const Duration(milliseconds: 250),
                  );
                }
              },
            ),
          if (details.meal.isEaten && state.analysis != null)
            MealObservationContext(analysis: state.analysis!),
          MealLowTreatmentsSection(details: details),
          MealReviewChapter(
            title: context.lang.mealFoodChapter,
            subtitle: context.lang.mealFoodChapterHint,
            icon: Icons.restaurant_rounded,
          ),
          if (!advanced.value && details.meal.isEaten)
            CurrentMealMacroComparison(details: details),
          if (details.meal.isEaten)
            SimilarMealsSection(
              key: ValueKey('similar-${details.meal.id}'),
              details: details,
            ),
          if (advanced.value || !details.meal.isEaten) ...[
            MealSnapshotsSection(details: details),
            MealNutritionAnalysisSection(details: details),
          ],
          MealReviewChapter(
            title: context.lang.mealDecisionsChapter,
            subtitle: context.lang.mealDecisionsChapterHint,
            icon: Icons.fact_check_outlined,
          ),
          if (details.meal.isEaten && state.analysis != null)
            MealStartContextSection(
              data: MealStartContextData(
                details: details,
                analysis: state.analysis!,
              ),
            ),
          if (advanced.value || !details.meal.isEaten || state.analysis == null)
            MealAdvisorResultSection(details: details),
          if (advanced.value || !details.meal.isEaten) ...[
            if (details.meal.isEaten)
              MealAdviceHistorySection(
                details: details,
                analysis: state.analysis,
              ),
            if (details.meal.isEaten && state.analysis != null)
              MealComparisonSection(
                details: details,
                analysis: state.analysis!,
              ),
            const SizedBox(height: 20),
            MealTechnicalSection(state: state),
          ],
        ],
      ),
    );
  }
}
