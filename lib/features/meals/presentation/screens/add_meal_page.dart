import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_time_anchor.dart';
import '../../../../common/widgets/form_step_header.dart';
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
    final step = useState(0);
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
    final ingredientCount = draft.mealIngredients.length;
    useEffect(() {
      final height = step.value == 0
          ? (0.46 + ingredientCount * 0.08).clamp(0.46, 0.9)
          : !retrospective && step.value == 1
          ? 0.44
          : 0.9;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) SheetHeightRequest(height).dispatch(context);
      });
      return null;
    }, [step.value, retrospective, ingredientCount]);
    final mealDraft = ref.read(mealDraftProvider.notifier);
    final isSaving = ref.watch(addMealControllerProvider).isLoading;
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

    void next() {
      if (busy) return;
      if (step.value == 0) {
        if (draft.mealIngredients.isNotEmpty) changeStep(1);
        return;
      }
      final form = timeFormKey.currentState;
      if (form == null || !form.validate()) return;
      form.save();
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
      changeStep(2);
    }

    return PopScope(
      canPop: step.value == 0 && !isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy && step.value > 0) changeStep(step.value - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: isSaving
                ? null
                : () {
                    if (step.value > 0) {
                      if (!isCopying) changeStep(step.value - 1);
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: FormStepHeader(
                  currentStep: step.value,
                  labels: [
                    context.lang.mealFlowComposition,
                    context.lang.mealFlowWhen,
                    context.lang.mealFlowReview,
                  ],
                ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: busy,
                  child: SingleChildScrollView(
                    key: ValueKey(step.value),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: switch (step.value) {
                      0 => MealCompositionStep(
                        retrospective: retrospective,
                        source: source.value,
                        isCopying: isCopying,
                        picker: (context) => showCopiedMealPicker(context, ref),
                        onPicked: (value) async {
                          final applied = await _copyFromSource(
                            context,
                            ref,
                            value,
                          );
                          if (applied && context.mounted) source.value = value;
                          return applied;
                        },
                      ),
                      1 => Form(
                        key: timeFormKey,
                        child: MealTimingStep(
                          key: ValueKey(timeFieldVersion.value),
                          retrospective: retrospective,
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
                          calculatorDate: retrospective ? initialEatenAt : null,
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
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Row(
            children: [
              if (step.value > 0) ...[
                TextButton(
                  onPressed: busy ? null : () => changeStep(step.value - 1),
                  child: Text(context.lang.mealFlowBack),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      busy || (step.value == 0 && draft.mealIngredients.isEmpty)
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          step.value < 2 ? Icons.arrow_forward : Icons.check,
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
        ),
      ),
    );
  }

  Future<CopiedMealType?> showCopiedMealPicker(
    BuildContext context,
    WidgetRef ref,
  ) {
    return showModalBottomSheet<CopiedMealType>(
      useRootNavigator: false,
      isScrollControlled: true,
      context: context,
      builder: (context) => CopiedMealPicker(
        initialQuery: ref.read(mealDraftProvider.notifier).usesAutomaticName
            ? ''
            : ref.read(mealDraftProvider).name.trim(),
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
          .read(addMealControllerProvider.notifier)
          .saveCurrentDraft(context.lang, retrospective: timing);
      if (context.mounted) {
        context.router.pop(meal);
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
