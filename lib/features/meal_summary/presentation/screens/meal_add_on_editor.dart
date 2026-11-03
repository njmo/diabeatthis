import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_activation_guard.dart';
import '../../../../common/meal/meal_display_name.dart';
import '../../../../common/widgets/meal_completion/meal_completion_save_button.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../domain/use_cases/finalize_meal_summary_use_case.dart';
import '../../domain/use_cases/record_meal_add_on_use_case.dart';
import '../controllers/meal_summary_controller.dart';
import '../models/meal_completion_portion_choice.dart';
import '../models/meal_summary_draft.dart';
import '../utils/meal_add_on_draft.dart';
import '../utils/open_meal_summary_aaps_suggestion.dart';
import '../widgets/meal_completion_quantity_section.dart';

class MealAddOnEditor extends ConsumerStatefulWidget {
  const MealAddOnEditor({super.key, required this.meal, this.totalMultiplier});

  final Meal meal;
  final double? totalMultiplier;

  @override
  ConsumerState<MealAddOnEditor> createState() => MealAddOnEditorState();
}

class MealAddOnEditorState extends ConsumerState<MealAddOnEditor> {
  bool initialized = false;
  bool saving = false;
  bool inputValid = true;
  String? error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(initializeDraft);
  }

  Future<void> initializeDraft() async {
    try {
      await ref.read(mealSummaryControllerProvider(widget.meal.id).future);
      if (!mounted) return;
      ref
          .read(mealSummaryControllerProvider(widget.meal.id).notifier)
          .prepareAddOn(totalMultiplier: widget.totalMultiplier);
      setState(() => initialized = true);
    } catch (_) {
      // The provider exposes its load failure in the body below.
      if (mounted) setState(() => initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mealSummaryControllerProvider(widget.meal.id));
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: Text(context.lang.mealSummaryExtraTitle)),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (failure, _) =>
              Center(child: Text(context.lang.mealSummaryLoadError(failure))),
          data: (draft) {
            if (!initialized) {
              return const Center(child: CircularProgressIndicator());
            }
            final valid = inputValid && mealAddOnAmountsValid(draft);
            return SafeArea(
              child: AbsorbPointer(
                absorbing: saving,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            mealDisplayName(widget.meal.name),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(context.lang.mealAddOnEditHint),
                          const SizedBox(height: 16),
                          MealCompletionQuantitySection(
                            draft: draft,
                            choice: MealCompletionPortionChoice.adjusted,
                            showChoice: false,
                            addOnOnly: true,
                            showConfidence: false,
                            enabled: !saving,
                            onChoiceChanged: (_) {},
                            onInputValidityChanged: (value) =>
                                setState(() => inputValid = value),
                          ),
                          const SizedBox(height: 16),
                          if (!valid && error == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(context.lang.mealAddOnNoIncrease),
                            ),
                        ],
                      ),
                    ),
                    MealCompletionSaveButton(
                      onPressed: valid && !saving ? () => save(draft) : null,
                      saving: saving,
                      icon: Icons.restaurant,
                      error: error,
                      label: context.lang.mealAddOnEatingAction,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> save(MealSummaryDraft draft) async {
    if (saving || !inputValid || !mealAddOnAmountsValid(draft)) return;
    setState(() {
      saving = true;
      error = null;
    });
    late final MealAddOnResult result;
    try {
      result = await ref.read(recordMealAddOnUseCaseProvider).call(draft);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = switch (failure) {
            MealSummaryCannotFinishException(:final userMessage) => userMessage,
            MealActivationException(:final userMessage) => userMessage,
            _ => context.lang.mealCompletionSaveError,
          };
        });
      }
      return;
    }
    if (!mounted) return;
    try {
      await openMealAapsCarbsSuggestion(
        context: context,
        ref: ref,
        mealId: result.meal.id,
        mealName: result.meal.name,
        aapsCarbs: result.aapsCarbs,
      );
    } catch (failure, stackTrace) {
      Log.e(
        'MealAddOnEditor',
        'Could not open the saved add-on suggestion',
        error: failure,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.lang.mealAddOnSavedContinueEating)),
    );
    setState(() => saving = false);
    Navigator.of(context).pop();
  }
}
