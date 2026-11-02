import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_completion_timing.dart';
import '../../../../common/meal/meal_display_name.dart';
import '../../../../common/widgets/date_time_boundary_builder.dart';
import '../../../../common/widgets/meal_completion/meal_completion_choice_sheet.dart';
import '../../../../common/widgets/meal_completion/meal_completion_save_button.dart';
import '../../../../common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import '../../../../core/logger/logger.dart';
import '../../../meals/data/providers/meal_activation_guard_provider.dart';
import '../../domain/use_cases/complete_meal_use_case.dart';
import '../../domain/use_cases/finalize_meal_summary_use_case.dart';
import '../../domain/utils/meal_completion_amounts.dart';
import '../controllers/meal_completion_controller.dart';
import '../controllers/meal_summary_controller.dart';
import '../models/meal_completion_portion_choice.dart';
import '../models/meal_summary_draft.dart';
import '../providers/meal_completion_context_provider.dart';
import '../utils/add_meal_summary_extra_item.dart';
import '../utils/meal_completion_shortfall.dart';
import '../utils/meal_summary_carbs_delta.dart';
import '../utils/open_meal_completion_result.dart';
import '../widgets/meal_completion_carbs_hint.dart';
import '../widgets/meal_completion_quantity_section.dart';
import '../widgets/meal_completion_review.dart';

class MealCompletionView extends ConsumerStatefulWidget {
  const MealCompletionView({
    super.key,
    required this.mealId,
    this.confirmedEatingEndedAt,
    this.compactChoice = false,
    this.startAdjusted = false,
    this.onEarlierRequested,
  });

  final int mealId;
  final DateTime? confirmedEatingEndedAt;
  final bool compactChoice;
  final bool startAdjusted;
  final VoidCallback? onEarlierRequested;

  @override
  ConsumerState<MealCompletionView> createState() => MealCompletionViewState();
}

class MealCompletionViewState extends ConsumerState<MealCompletionView> {
  MealCompletionPortionChoice? choice;
  DateTime? endedAt;
  bool initializedTiming = false;
  bool saving = false;
  bool reviewing = false;
  bool finishingRefill = false;
  bool editingShortfall = false;
  bool quantityInputValid = true;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.startAdjusted) choice = MealCompletionPortionChoice.adjusted;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mealSummaryControllerProvider(widget.mealId));
    final completion = ref.watch(mealCompletionContextProvider(widget.mealId));
    if (widget.compactChoice) {
      return data.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (failure, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text(context.lang.mealSummaryLoadError(failure)),
        ),
        data: (_) => completion.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (failure, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(context.lang.mealSummaryLoadError(failure)),
          ),
          data: (details) {
            initializeTiming(details);
            return MealCompletionChoiceSheet(
              mealName: mealDisplayName(details.meal.name),
              requiresBolus:
                  details.requiresBolus ||
                  details.meal.status == 'eating-then-bolus',
              saving: saving || reviewing,
              error: error,
              onEarlier: widget.onEarlierRequested,
              onClose: () => closeChoice(),
              onAsPlanned: () =>
                  selectChoice(MealCompletionPortionChoice.asReported),
              onDifferent: () => closeChoice(editAmounts: true),
            );
          },
        ),
      );
    }
    return DateTimeBoundaryBuilder(
      at: endedAt,
      builder: (context, now) => Scaffold(
        appBar: AppBar(title: Text(context.lang.mealCompletionTitle)),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text(context.lang.mealSummaryLoadError(e))),
          data: (draft) => completion.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(context.lang.mealSummaryLoadError(e))),
            data: (details) {
              initializeTiming(details);
              final amountsValid = mealCompletionAmountsValid(
                draft,
                inferMealCompletionChoice(draft),
              );
              final valid =
                  quantityInputValid &&
                  choice != null &&
                  amountsValid &&
                  details.timing.isValidEnd(endedAt, now);
              final quantityError =
                  choice == MealCompletionPortionChoice.adjusted &&
                      !amountsValid
                  ? mealCompletionHasNoFood(draft)
                        ? context.lang.mealCompletionNothingEaten
                        : context.lang.mealCompletionInvalidAmount
                  : null;
              final reported = calculateMealSummaryCarbsDelta(
                draft,
              ).usesReportedBaseline;
              return SafeArea(
                child: AbsorbPointer(
                  absorbing: saving || reviewing,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              mealDisplayName(details.meal.name),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (isQuickMealName(details.meal.name))
                              Text(
                                context.lang.mealProgressQuickMeal,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: 16),
                            if (reported) ...[
                              Text(context.lang.mealCompletionReportedNote),
                              const SizedBox(height: 12),
                            ],
                            DateTimeBoundaryBuilder(
                              at: details.timing.startedAt?.add(
                                MealCompletionTiming.lateConfirmationThreshold,
                              ),
                              builder: (context, reportingNow) =>
                                  MealCompletionQuantitySection(
                                    draft: draft,
                                    choice: choice,
                                    showChoice: !widget.startAdjusted,
                                    showConfidence: details.timing.isLateReport(
                                      reportingNow,
                                    ),
                                    requiresBolus: details.requiresBolus,
                                    enabled: !saving && !reviewing,
                                    onInputValidityChanged: (value) =>
                                        setState(() {
                                          quantityInputValid = value;
                                        }),
                                    onChoiceChanged: selectChoice,
                                    onAddFood: addFood,
                                  ),
                            ),
                            if (choice ==
                                MealCompletionPortionChoice.adjusted) ...[
                              const SizedBox(height: 16),
                              MealCompletionCarbsHint(
                                draft: draft,
                                hasRecordedBolus: details.hasRecordedBolus,
                                requiresBolus: details.requiresBolus,
                                coveredNetCarbs: details.coveredNetCarbs,
                              ),
                            ],
                            if (choice == MealCompletionPortionChoice.adjusted)
                              MealCompletionReview(draft: draft),
                            const SizedBox(height: 20),
                            if (finishingRefill)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  context.lang.mealCompletionRefillPending,
                                ),
                              ),
                            if (choice !=
                                    MealCompletionPortionChoice.adjusted &&
                                error != null)
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (saving &&
                                choice ==
                                    MealCompletionPortionChoice.asReported)
                              const Center(child: CircularProgressIndicator()),
                          ],
                        ),
                      ),
                      if (choice == MealCompletionPortionChoice.adjusted)
                        MealCompletionSaveButton(
                          onPressed: valid && !saving && !reviewing
                              ? () => save(draft)
                              : null,
                          saving: saving,
                          error: error ?? quantityError,
                          label: finishingRefill
                              ? context.lang.mealCompletionRefillFinished
                              : details.requiresBolus ||
                                    details.meal.status == 'eating-then-bolus'
                              ? context.lang.mealCompletionSaveBeforeBolus
                              : context.lang.mealCompletionSave,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void initializeTiming(MealCompletionContext details) {
    if (initializedTiming) return;
    initializedTiming = true;
    endedAt = widget.confirmedEatingEndedAt ?? details.timing.endedAt;
  }

  void closeChoice({bool editAmounts = false}) {
    if (saving || reviewing || (editAmounts && endedAt == null)) return;
    setState(() => reviewing = true);
    Navigator.pop(context, editAmounts ? endedAt : null);
  }

  Future<void> selectChoice(MealCompletionPortionChoice value) async {
    if (saving || reviewing) return;
    if (value == MealCompletionPortionChoice.asReported) {
      finishingRefill = false;
      ref
          .read(mealSummaryControllerProvider(widget.mealId).notifier)
          .setReportedPortionFactor(1, clearExtras: true);
    }
    setState(() {
      choice = value;
      error = null;
      quantityInputValid = true;
    });
    if (value == MealCompletionPortionChoice.asReported) {
      await save(
        ref.read(mealSummaryControllerProvider(widget.mealId)).requireValue,
      );
    }
  }

  Future<void> save(MealSummaryDraft draft) async {
    if (choice == null || endedAt == null || saving || reviewing) return;
    if (!mealCompletionAmountsValid(draft, inferMealCompletionChoice(draft))) {
      setState(() {
        error = mealCompletionHasNoFood(draft)
            ? context.lang.mealCompletionNothingEaten
            : context.lang.mealCompletionInvalidAmount;
      });
      return;
    }
    setState(() => reviewing = true);
    late final MealCompletionContext details;
    MealShortfallAction? shortfallAction;
    try {
      details = await ref
          .read(mealCompletionControllerProvider)
          .refresh(widget.mealId);
      if (!mounted) return;
      if (finishingRefill && !await canContinueEating()) return;
      if (ref
          .read(mealCompletionControllerProvider)
          .needsReview(draft, details)) {
        shortfallAction = await reviewShortfall(draft, details);
        if (!mounted ||
            (shortfallAction != MealShortfallAction.saveActual &&
                shortfallAction != MealShortfallAction.saveAndCorrect)) {
          return;
        }
      }
    } catch (_) {
      if (mounted) setState(() => error = context.lang.mealCompletionSaveError);
      return;
    } finally {
      if (mounted) setState(() => reviewing = false);
    }
    if (!mounted) return;
    // A refill is confirmed as eaten by this final action, not by opening the
    // editor. Ordinary corrections retain their explicitly selected time.
    final completionTime = mealCompletionEndForSave(
      confirmedEndedAt: endedAt!,
      finishedRefill: finishingRefill,
      now: clock.now(),
    );
    setState(() {
      saving = true;
      error = null;
    });
    late final MealCompletionResult result;
    try {
      result = await ref
          .read(mealCompletionControllerProvider)
          .complete(
            draft: draft,
            details: details,
            action: shortfallAction,
            endedAt: completionTime,
            finishingRefill: finishingRefill,
          );
    } on MealSummaryCannotFinishException catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.userMessage;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = context.lang.mealCompletionSaveError;
        });
      }
      return;
    }
    if (!mounted) return;
    try {
      await openMealCompletionResult(
        context: context,
        ref: ref,
        result: result,
      );
    } catch (failure, stackTrace) {
      Log.e(
        'MealCompletionView',
        'Could not open the saved meal suggestion',
        error: failure,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.requiresBolus
              ? context.lang.mealCompletionBeforeBolusSaved
              : context.lang.mealCompletionSaved,
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<bool> canContinueEating() async {
    ref.invalidate(mealBlockingActivationProvider(widget.mealId));
    final blocking = await ref.read(
      mealBlockingActivationProvider(widget.mealId).future,
    );
    if (!mounted) return false;
    if (blocking == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.lang.mealStatusActivationBlocked(
            mealDisplayName(blocking.name),
          ),
        ),
      ),
    );
    return false;
  }

  Future<MealShortfallAction?> reviewShortfall(
    MealSummaryDraft draft,
    MealCompletionContext details,
  ) async {
    final delta = calculateMealSummaryCarbsDelta(draft);
    if (!mounted) return null;
    final action = await showDialog<MealShortfallAction>(
      context: context,
      builder: (_) => MealShortfallReviewDialog(
        actualCarbs: calculateMealSummaryConsumedCarbs(draft).ceil(),
        missingCarbs: mealCompletionShortfallCarbs(
          draft,
          coveredNetCarbs: details.coveredNetCarbs,
        ).round(),
        usesReportedBaseline: delta.usesReportedBaseline,
        usesBolusCoverage: details.coveredNetCarbs != null,
        correctionCarbs: details.requiresBolus ? 0 : delta.roundedTotal,
      ),
    );
    if (!mounted) return null;
    switch (action) {
      case MealShortfallAction.saveActual:
      case MealShortfallAction.saveAndCorrect:
        return action;
      case MealShortfallAction.editAmounts:
        setState(() {
          editingShortfall = true;
          choice = MealCompletionPortionChoice.adjusted;
        });
        return null;
      case null:
        return null;
    }
  }

  Future<void> addFood() async {
    if (saving || reviewing) return;
    if (editingShortfall && !await canContinueEating()) return;
    if (!mounted) return;
    final added = await addMealSummaryExtraItem(
      context: context,
      ref: ref,
      mealId: widget.mealId,
    );
    if (added && mounted && editingShortfall) {
      setState(() => finishingRefill = true);
    }
  }
}
