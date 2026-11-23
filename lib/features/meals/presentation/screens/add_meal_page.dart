import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_time_anchor.dart';
import '../../../../common/planning/meal_form_actions.dart';
import '../../../../common/routing/form_route_guard.dart';
import '../../../../common/widgets/form_action_bar.dart';
import '../../../../common/widgets/form_step_header.dart';
import '../../../../common/widgets/responsive_bottom_sheet.dart';
import '../../../../common/widgets/sheet_content_height_request.dart';
import '../../../../common/widgets/sheet_content_section_reporter.dart';
import '../../../../common/widgets/sheet_height_request.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/models/retrospective_meal_timing.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../controllers/add_meal_controller.dart';
import '../controllers/copy_meal_source_controller.dart';
import '../widgets/add_meal/meal_composition_step.dart';
import '../widgets/add_meal/meal_review_step.dart';
import '../widgets/add_meal/meal_timing_step.dart';
import '../widgets/copied_meal_picker.dart';

@RoutePage()
class AddMealPage extends HookConsumerWidget {
  final bool retrospective;

  /// The calculator entry time, initially used as the insulin reference.
  final DateTime? initialEatenAt;
  const AddMealPage({
    super.key,
    this.retrospective = false,
    this.initialEatenAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(mealFormActionsProvider);
    useListenable(actions);
    final step = useState(0);
    final summaryFromIngredients = useState(false);
    final timing = useState(const RetrospectiveMealTiming());
    final selectedDate = useState(initialEatenAt);
    final timeAnchor = useState(
      initialEatenAt != null && retrospective
          ? MealTimeAnchor.insulin
          : MealTimeAnchor.eatingStart,
    );
    final timeFieldVersion = useState(0);
    final source = useState<CopiedMealType?>(null);
    final timeFormKey = useMemoized(GlobalKey<FormState>.new);
    final reviewFormKey = useMemoized(GlobalKey<FormState>.new);
    final draft = ref.watch(mealDraftProvider);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) const SheetHeightRequest(0.75).dispatch(context);
      });
      return null;
    }, const []);
    final mealDraft = ref.read(mealDraftProvider.notifier);
    final isSaving =
        actions.saving || ref.watch(addMealControllerProvider).isLoading;
    final isCopying = ref.watch(copyMealSourceControllerProvider).isLoading;
    final busy = isSaving || isCopying;
    final copyController = ref.read(copyMealSourceControllerProvider.notifier);
    useEffect(() => copyController.cancelPendingCopy, [copyController]);

    void updatePlannedStart() {
      final reference = selectedDate.value;
      if (reference == null) return;
      mealDraft.setPlannedAt(
        retrospective
            ? timing.value.startFromReference(reference, timeAnchor.value)
            : reference,
      );
    }

    void changeStep(int value) {
      FocusScope.of(context).unfocus();
      step.value = value;
    }

    void planWithoutHour() {
      selectedDate.value = null;
      timeFieldVersion.value++;
      mealDraft.planWithoutHour(clock.now());
    }

    void back() {
      changeStep(
        step.value == 2 && summaryFromIngredients.value ? 0 : step.value - 1,
      );
    }

    void skipToReview() {
      if (busy ||
          draft.mealIngredients.isEmpty ||
          !actions.canContinue(draft)) {
        return;
      }
      planWithoutHour();
      summaryFromIngredients.value = true;
      changeStep(2);
    }

    void next() {
      if (busy) return;
      if (step.value == 0) {
        if (draft.mealIngredients.isNotEmpty && actions.canContinue(draft)) {
          changeStep(1);
        }
        return;
      }
      final form = timeFormKey.currentState;
      if (ref.read(mealDraftProvider).plannedDay == null) {
        if (form == null || !form.validate()) return;
        form.save();
      }
      if (retrospective) {
        try {
          timing.value.validate(
            ref.read(mealDraftProvider).plannedAt,
            clock.now(),
          );
        } on ArgumentError catch (error) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${error.message}')));
          return;
        }
      }
      summaryFromIngredients.value = false;
      changeStep(2);
    }

    return PopScope(
      canPop: step.value == 0 && !isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy && step.value > 0) back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: isSaving
                ? null
                : () {
                    if (step.value > 0) {
                      if (!isCopying) back();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
          ),
          title: Text(
            retrospective
                ? context.lang.uiRecordAPastMeal
                : context.lang.addMealTitle,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SheetContentSectionReporter(
                section: SheetContentSection.header,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: FormStepHeader(
                    currentStep: step.value,
                    labels: [
                      context.lang.mealFlowComposition,
                      context.lang.mealFlowWhen,
                      context.lang.mealFlowReview,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: busy,
                  child: SingleChildScrollView(
                    key: ValueKey(step.value),
                    child: SheetContentSectionReporter(
                      section: SheetContentSection.body,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: switch (step.value) {
                          0 => MealCompositionStep(
                            retrospective: retrospective,
                            source: source.value,
                            isCopying: isCopying,
                            picker: (context) =>
                                showCopiedMealPicker(context, ref),
                            onPicked: (value) async {
                              final applied = await _copyFromSource(
                                context,
                                ref,
                                value,
                              );
                              if (applied && context.mounted) {
                                source.value = value;
                              }
                              return applied;
                            },
                          ),
                          1 => Form(
                            key: timeFormKey,
                            child: MealTimingStep(
                              planningHorizonDays: actions.planningHorizonDays,
                              key: ValueKey(timeFieldVersion.value),
                              retrospective: retrospective,
                              withoutHour: draft.plannedDay != null,
                              onWithoutHour: planWithoutHour,
                              selectedDate: selectedDate.value,
                              anchor: timeAnchor.value,
                              onAnchorChanged: (value) {
                                timeAnchor.value = value;
                                updatePlannedStart();
                              },
                              onCalculatorSelected: initialEatenAt == null
                                  ? null
                                  : () {
                                      timeAnchor.value = MealTimeAnchor.insulin;
                                      selectedDate.value = initialEatenAt;
                                      timeFieldVersion.value++;
                                      updatePlannedStart();
                                    },
                              calculatorDate: retrospective
                                  ? initialEatenAt
                                  : null,
                              onDateChanged: (value) {
                                selectedDate.value = value;
                                updatePlannedStart();
                              },
                              timing: timing.value,
                              onTimingChanged: (value) {
                                timing.value = value;
                                updatePlannedStart();
                              },
                            ),
                          ),
                          _ => Form(
                            key: reviewFormKey,
                            child: MealReviewStep(
                              source: source.value,
                              timing: retrospective ? timing.value : null,
                              onChangeComposition: () => changeStep(0),
                              onChangeTime: () => changeStep(1),
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SheetContentSectionReporter(
          section: SheetContentSection.footer,
          child: FormActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step.value == 0 && !retrospective) ...[
                  OutlinedButton.icon(
                    onPressed: busy || draft.mealIngredients.isEmpty
                        ? null
                        : skipToReview,
                    icon: const Icon(Icons.today_outlined),
                    label: Text(context.lang.mealPlanTodayWithoutHour),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    if (step.value > 0) ...[
                      TextButton(
                        onPressed: busy ? null : back,
                        child: Text(context.lang.mealFlowBack),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            busy ||
                                (step.value == 0 &&
                                    draft.mealIngredients.isEmpty)
                            ? null
                            : step.value < 2
                            ? next
                            : () => _saveMeal(
                                context: context,
                                ref: ref,
                                formKey: reviewFormKey,
                                timing: retrospective ? timing.value : null,
                              ),
                        icon: isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                step.value < 2
                                    ? Icons.arrow_forward
                                    : Icons.check,
                              ),
                        label: Text(
                          isSaving
                              ? context.lang.addMealSaving
                              : switch (step.value) {
                                  0 => context.lang.mealFlowNextTime,
                                  1 => context.lang.mealFlowNextReview,
                                  _ =>
                                    !retrospective
                                        ? context.lang.mealFlowPlan
                                        : initialEatenAt != null
                                        ? context.lang.mealFlowSaveAndLink
                                        : context.lang.addMealSave,
                                },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<CopiedMealType?> showCopiedMealPicker(
    BuildContext context,
    WidgetRef ref,
  ) {
    final guard = formRouteGuardOf(context);
    final container = ProviderScope.containerOf(context);
    return showResponsiveBottomSheet<CopiedMealType>(
      useRootNavigator: false,
      isScrollControlled: true,
      context: context,
      builder: (context) => guard(
        UncontrolledProviderScope(
          container: container,
          child: CopiedMealPicker(
            initialQuery: ref.read(mealDraftProvider.notifier).usesAutomaticName
                ? ''
                : ref.read(mealDraftProvider).name.trim(),
          ),
        ),
      ),
    );
  }

  Future<bool> _copyFromSource(
    BuildContext context,
    WidgetRef ref,
    CopiedMealType source,
  ) async {
    try {
      return await ref
          .read(copyMealSourceControllerProvider.notifier)
          .copyFromSource(source);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.mealIngredientsLoadError(error))),
        );
      }
      return false;
    }
  }

  Future<void> _saveMeal({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    RetrospectiveMealTiming? timing,
  }) async {
    if (ref.read(copyMealSourceControllerProvider).isLoading ||
        ref.read(addMealControllerProvider).isLoading) {
      return;
    }
    final formState = formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    formState.save();
    try {
      final meal = await ref
          .read(mealFormActionsProvider)
          .save(ref, context.lang, retrospective: timing);
      if (context.mounted) {
        ref.read(mealFormActionsProvider).close(context, meal);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.addMealSaveError(e))),
        );
      }
    }
  }
}
