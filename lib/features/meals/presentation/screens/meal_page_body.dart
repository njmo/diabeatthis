import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/details/meal_preview_controller.dart';
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
import '../widgets/meal_details/meal_observation_context.dart';
import '../widgets/meal_details/meal_outcome_section.dart';
import '../widgets/meal_details/meal_portion_card.dart';
import '../widgets/meal_details/meal_preview_actions.dart';
import '../widgets/meal_details/meal_preview_header.dart';
import '../widgets/meal_details/meal_saved_information_card.dart';
import '../widgets/meal_details/planned_meal_preview.dart';
import '../widgets/meal_details/similar_meals_section.dart';

class MealPageBody extends HookConsumerWidget {
  final MealPageState state;
  const MealPageBody({super.key, required this.state, this.presentation});
  final MealPreviewController? presentation;
  MealPageBody.controlled({
    super.key,
    required MealPreviewController controller,
  }) : state = controller.state,
       presentation = controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = presentation ?? PatientMealPreviewController(state);
    final canUseLocalActions = source.canUseLocalActions;
    final chartKey = useMemoized(() => GlobalKey());
    final sharedSelection = useState<DateTime?>(null);
    final details = state.details;
    final complete =
        source.showAnalysis &&
        state.analysis?.hasFullGlucoseWindow == true &&
        details.meal.isEaten;
    // Before eating the overview only held the actions button, which now
    // lives above the tabs, so the empty tab is left out.
    final showOverview =
        complete ||
        details.meal.isEaten ||
        (!canUseLocalActions && state.analysis != null);
    final chart = MealChartsSection(
      key: chartKey,
      details: details,
      analysis: state.analysis,
      analysisError: state.analysisError,
      selectedTimestamp: canUseLocalActions
          ? state.selectedTimestamp
          : sharedSelection.value,
      advanced: true,
      onTimestampSelected: canUseLocalActions
          ? null
          : (time) => sharedSelection.value = time,
    );
    final controller = useTabController(
      initialLength: !source.showAnalysis
          ? 2
          : complete && canUseLocalActions
          ? 6
          : showOverview
          ? 3
          : 2,
      keys: [
        details.meal.id,
        complete,
        showOverview,
        source.showAnalysis,
        canUseLocalActions,
      ],
    );
    if (details.meal.status == 'planned') {
      return PlannedMealPreview(
        state: state,
        canUseLocalActions: canUseLocalActions,
        onOpenIngredient: source.onOpenIngredient,
      );
    }
    final lang = context.lang;
    if (!source.showAnalysis) {
      return SwipeableCards(
        key: ValueKey(('shared-meal', details.meal.id)),
        controller: controller,
        showPageControls: false,
        header: MealPreviewHeader(
          state: state,
          canUseLocalActions: canUseLocalActions,
          showAnalysis: source.showAnalysis,
        ),
        labels: [lang.mealPortionCardTitle, lang.mealApplicationContextTitle],
        children: [
          MealPortionCard(
            details: details,
            showHeader: false,
            canUseLocalActions: canUseLocalActions,
            onOpenIngredient: source.onOpenIngredient,
          ),
          MealSavedInformationCard(state: state),
        ],
      );
    }

    final overview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (complete || (!canUseLocalActions && state.analysis != null)) ...[
          MealOutcomeSection(
            analysis: state.analysis!,
            hasLocalContext: canUseLocalActions,
            advanced: true,
            readableSummary: true,
            chart: chart,
          ),
          if (!canUseLocalActions)
            MealObservationContext(analysis: state.analysis!),
          if (canUseLocalActions && state.showHistoryDownload)
            MealHistoryDownloadButton(state: state, inline: true),
        ] else if (details.meal.isEaten && canUseLocalActions)
          MealGlucoseCard(state: state),
      ],
    );
    return SwipeableCards(
      key: ValueKey((details.meal.id, complete, showOverview)),
      controller: controller,
      showPageControls: false,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MealPreviewHeader(
            state: state,
            canUseLocalActions: canUseLocalActions,
          ),
          if (canUseLocalActions) ...[
            const SizedBox(height: 12),
            MealPreviewActions(meal: details.meal),
          ],
        ],
      ),
      labels: complete && canUseLocalActions
          ? [
              lang.mealGlucoseChapter,
              lang.mealCardBeforeTab,
              lang.mealPortionCardTitle,
              lang.mealCardEventsTab,
              lang.similarMealsTitle,
              lang.mealApplicationContextTitle,
            ]
          : [
              if (showOverview)
                complete
                    ? lang.mealGlucoseChapter
                    : details.meal.isEaten
                    ? lang.mealCardObservation
                    : lang.mealCardMealTab,
              lang.mealPortionCardTitle,
              lang.mealApplicationContextTitle,
            ],
      children: [
        if (showOverview) overview,
        if (complete && canUseLocalActions)
          MealBeforeCard(
            data: MealStartContextData(
              details: details,
              analysis: state.analysis!,
            ),
          ),
        MealPortionCard(
          details: details,
          showHeader: false,
          canUseLocalActions: canUseLocalActions,
          onOpenIngredient: source.onOpenIngredient,
        ),
        if (complete && canUseLocalActions) ...[
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
        if (canUseLocalActions)
          MealApplicationContext(state: state)
        else
          MealSavedInformationCard(state: state),
      ],
    );
  }
}
