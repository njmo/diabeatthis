import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/platform/aaps_suggestion_prompt.dart';
import '../../../../common/widgets/form_section.dart';
import '../../../dashboard/data/utils/meal_advisor.dart';
import '../../../meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../domain/use_cases/finalize_meal_summary_use_case.dart';
import '../../domain/utils/meal_add_on_status.dart';
import '../controllers/meal_summary_controller.dart';
import '../models/meal_summary_draft.dart';
import '../providers/meal_summary_item_ids_provider.dart';
import '../utils/meal_summary_aaps_suggestion.dart';
import '../utils/meal_summary_carbs_delta.dart';
import '../widgets/meal_summary_carbs_hint_card.dart';
import '../widgets/meal_summary_extra_items_section.dart';
import '../widgets/meal_summary_item_row.dart';

@RoutePage()
class MealSummaryPage extends ConsumerWidget {
  final int mealId;

  const MealSummaryPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDraft = ref.watch(mealSummaryControllerProvider(mealId));
    final itemIds = ref.watch(mealSummaryItemIdsProvider(mealId));
    final notifier = ref.read(mealSummaryControllerProvider(mealId).notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.lang.mealSummaryTitle)),
      body: asyncDraft.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Center(child: Text(context.lang.mealSummaryLoadError(e))),
        data: (draft) {
          final addOnAlreadyReported = _hasReportedAddOn(draft);
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  context.lang.mealSummaryCheckTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  addOnAlreadyReported
                      ? context.lang.mealSummaryAddOnReportedHint
                      : context.lang.mealSummaryDefaultHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                MealSummaryCarbsHintCard(
                  draft: draft,
                  addOnAlreadyReported: addOnAlreadyReported,
                ),
                const SizedBox(height: 24),
                FormSection(
                  icon: Icons.restaurant,
                  title: context.lang.mealSummaryPlannedIngredientsTitle,
                  subtitle: context.lang.mealSummaryPlannedIngredientsSubtitle,
                  children: [
                    for (final itemId in itemIds)
                      MealSummaryItemRow(
                        mealId: mealId,
                        mealIngredientId: itemId,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                MealSummaryExtraItemsSection(
                  mealId: mealId,
                  items: draft.extraItems,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: asyncDraft.maybeWhen(
        data: (draft) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_hasReportedAddOn(draft)) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _saveSummary(
                      context: context,
                      ref: ref,
                      notifier: notifier,
                      draft: draft,
                      mode: MealSummarySaveMode.continueEating,
                    ),
                    icon: const Icon(Icons.restaurant),
                    label: Text(context.lang.mealSummarySaveAddOn),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _saveSummary(
                    context: context,
                    ref: ref,
                    notifier: notifier,
                    draft: draft,
                    mode: MealSummarySaveMode.finishMeal,
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(context.lang.mealSummaryFinishMeal),
                ),
              ),
            ],
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _saveSummary({
    required BuildContext context,
    required WidgetRef ref,
    required MealSummaryControllerNotifier notifier,
    required MealSummaryDraft draft,
    required MealSummarySaveMode mode,
  }) async {
    final delta = calculateMealSummaryCarbsDelta(draft);
    try {
      await notifier.saveSummary(mode: mode);
    } on MealSummaryCannotFinishException catch (e) {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.lang.mealSummaryBolusNotConfirmedTitle),
          content: Text(e.userMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.lang.notificationActionOk),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_dialogTitle(context.lang, delta, draft)),
        content: Text(_dialogMessage(context.lang, delta, mode, draft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.lang.notificationActionOk),
          ),
        ],
      ),
    );

    if (context.mounted) {
      await _openAapsForSummaryDelta(
        context: context,
        ref: ref,
        draft: draft,
        delta: delta,
      );
    }

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _openAapsForSummaryDelta({
    required BuildContext context,
    required WidgetRef ref,
    required MealSummaryDraft draft,
    required MealSummaryCarbsDelta delta,
  }) async {
    final aapsCarbs = calculateMealSummaryAapsCarbs(draft);
    if (!shouldOpenAapsForMealSummaryAapsCarbs(aapsCarbs)) {
      return;
    }

    final extendedCarbsScheduleSettings = aapsCarbs.extendedCarbs > 0
        ? MealAdvisor(
            config: MealAdvisorConfig(
              extendedCarbsScheduleSettings: await ref.read(
                extendedCarbsScheduleSettingsProvider.future,
              ),
            ),
          ).getPostMealExtendedCarbsScheduleSettings()
        : null;
    final event = buildMealSummaryAapsSuggestionEvent(
      aapsCarbs: aapsCarbs,
      extendedCarbsScheduleSettings: extendedCarbsScheduleSettings,
    );

    if (event == null || !context.mounted) {
      return;
    }

    await openAapsWithSuggestionNotification(
      context: context,
      ref: ref,
      event: event,
    );

    // TODO: If AAPS cannot be opened, this page is popped immediately after
    // this method returns, so the fallback SnackBar can be easy to miss.
    // Consider returning the launch result and keeping the summary visible on
    // failure, or showing the fallback message in the parent route.
  }

  String _dialogTitle(
    AppLocalizations lang,
    MealSummaryCarbsDelta delta,
    MealSummaryDraft draft,
  ) {
    final addOnAlreadyReported = _hasReportedAddOn(draft);

    if (addOnAlreadyReported && delta.isNeutral) {
      return lang.mealSummarySavedTitle;
    }

    if (delta.isPositive) {
      return addOnAlreadyReported
          ? lang.mealSummaryAddCarbsInAapsTitle(delta.roundedTotal)
          : lang.mealSummaryPositiveCarbsTitle(delta.roundedTotal);
    }
    if (delta.isNegative) {
      return addOnAlreadyReported
          ? lang.mealSummaryAapsCarbsTitle(delta.roundedTotal)
          : lang.mealSummaryNegativeCarbsTitle(delta.roundedTotal);
    }
    return lang.mealSummaryNoCarbsChangeTitle;
  }

  String _dialogMessage(
    AppLocalizations lang,
    MealSummaryCarbsDelta delta,
    MealSummarySaveMode mode,
    MealSummaryDraft draft,
  ) {
    final addOnAlreadyReported = _hasReportedAddOn(draft);

    if (addOnAlreadyReported && delta.isNeutral) {
      return lang.mealSummaryAddOnAlreadyReportedMessage;
    }

    final suffix = mode == MealSummarySaveMode.continueEating
        ? lang.mealSummaryContinueEatingSuffix
        : '';

    if (delta.isPositive) {
      if (addOnAlreadyReported) {
        return lang.mealSummaryPositiveReportedMessage(
          delta.roundedTotal,
          suffix,
        );
      }
      return lang.mealSummaryPositiveMessage(delta.roundedTotal, suffix);
    }
    if (delta.isNegative) {
      if (addOnAlreadyReported) {
        return lang.mealSummaryNegativeReportedMessage(
          delta.roundedTotal.abs(),
          delta.roundedTotal,
          suffix,
        );
      }
      return lang.mealSummaryNegativeMessage(delta.roundedTotal.abs(), suffix);
    }
    return lang.mealSummaryNeutralMessage(suffix);
  }

  bool _hasReportedAddOn(MealSummaryDraft draft) {
    return mealSummaryHasReportedAddOn(
      status: draft.mealStatus,
      usesReportedBaseline: calculateMealSummaryCarbsDelta(
        draft,
      ).usesReportedBaseline,
    );
  }
}
