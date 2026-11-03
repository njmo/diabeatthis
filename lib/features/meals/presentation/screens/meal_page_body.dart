import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/swipeable_cards.dart';
import '../../data/models/meal_start_context_data.dart';
import '../controllers/meal_details_controller.dart';
import '../models/meal_page_state.dart';
import '../widgets/meal_details/meal_application_context.dart';
import '../widgets/meal_details/meal_before_card.dart';
import '../widgets/meal_details/meal_charts_section.dart';
import '../widgets/meal_details/meal_comparison_section.dart';
import '../widgets/meal_details/meal_events_card.dart';
import '../widgets/meal_details/meal_glucose_card.dart';
import '../widgets/meal_details/meal_history_download_button.dart';
import '../widgets/meal_details/meal_outcome_section.dart';
import '../widgets/meal_details/meal_portion_card.dart';
import '../widgets/meal_details/meal_preview_actions.dart';
import '../widgets/meal_details/meal_preview_header.dart';
import '../widgets/meal_details/similar_meals_section.dart';

class MealPageBody extends HookConsumerWidget {
  final MealPageState state;
  const MealPageBody({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartKey = useMemoized(() => GlobalKey());
    final details = state.details;
    final complete =
        state.analysis?.hasFullGlucoseWindow == true && details.meal.isEaten;
    final chart = MealChartsSection(
      key: chartKey,
      details: details,
      analysis: state.analysis,
      analysisError: state.analysisError,
      selectedTimestamp: state.selectedTimestamp,
      advanced: true,
    );
    final controller = useTabController(
      initialLength: complete ? 6 : 3,
      keys: [details.meal.id, complete],
    );
    final lang = context.lang;
    final overview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealPreviewActions(meal: details.meal),
        if (complete) ...[
          MealOutcomeSection(
            analysis: state.analysis!,
            advanced: true,
            readableSummary: true,
            chart: chart,
          ),
          if (state.showHistoryDownload)
            MealHistoryDownloadButton(state: state, inline: true),
        ] else if (details.meal.isEaten)
          MealGlucoseCard(state: state),
      ],
    );
    return SwipeableCards(
      key: ValueKey((details.meal.id, complete)),
      controller: controller,
      showPageControls: false,
      header: MealPreviewHeader(state: state),
      labels: complete
          ? [
              lang.mealGlucoseChapter,
              lang.mealCardBeforeTab,
              lang.mealPortionCardTitle,
              lang.mealCardEventsTab,
              lang.similarMealsTitle,
              lang.mealApplicationContextTitle,
            ]
          : [
              details.meal.isEaten
                  ? lang.mealCardObservation
                  : lang.mealCardMealTab,
              lang.mealPortionCardTitle,
              lang.mealApplicationContextTitle,
            ],
      children: [
        overview,
        if (complete)
          MealBeforeCard(
            data: MealStartContextData(
              details: details,
              analysis: state.analysis!,
            ),
          ),
        MealPortionCard(details: details),
        if (complete) ...[
          MealEventsCard(
            details: details,
            analysis: state.analysis!,
            selectedTimestamp: state.selectedTimestamp,
            onSelected: (time) {
              ref
                  .read(mealDetailsControllerProvider(details.meal.id).notifier)
                  .selectTimestamp(time);
              controller.animateTo(0);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final chartContext = chartKey.currentContext;
                if (chartContext != null && chartContext.mounted) {
                  Scrollable.ensureVisible(
                    chartContext,
                    duration: const Duration(milliseconds: 250),
                  );
                }
              });
            },
          ),
          Column(
            children: [
              SimilarMealsSection(details: details, inline: true),
              MealComparisonSection(
                details: details,
                analysis: state.analysis!,
              ),
            ],
          ),
        ],
        MealApplicationContext(state: state),
      ],
    );
  }
}
