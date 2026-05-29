import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/models/low_treatment_sheet_state.dart';
import '../controllers/low_treatment_context_controller.dart';
import 'low_treatment_carbs_summary.dart';
import 'low_treatment_ingredients_list.dart';
import 'low_treatment_reason_selector.dart';
import 'low_treatment_related_record_field.dart';
import 'low_treatment_suggestion_summary.dart';
import 'quick_low_treatment_selector.dart';

Future<void> showLowTreatmentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => const LowTreatmentSheet(),
  );
}

enum LowTreatmentInputMode { quick, advanced }

class LowTreatmentSheet extends HookConsumerWidget {
  const LowTreatmentSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = useState(LowTreatmentInputMode.quick);
    final sheetStateAsync = ref.watch(lowTreatmentContextControllerProvider);
    final controller = ref.read(lowTreatmentContextControllerProvider.notifier);

    return sheetStateAsync.when(
      data: (sheetState) => LowTreatmentSheetContent(
        ref: ref,
        mode: mode,
        sheetState: sheetState,
        controller: controller,
      ),
      loading: () => const LowTreatmentSheetLoading(),
      error: (error, _) => LowTreatmentSheetError(error: error),
    );
  }
}

class LowTreatmentSheetContent extends StatelessWidget {
  const LowTreatmentSheetContent({
    super.key,
    required this.ref,
    required this.mode,
    required this.sheetState,
    required this.controller,
  });

  final WidgetRef ref;
  final ValueNotifier<LowTreatmentInputMode> mode;
  final LowTreatmentSheetState sheetState;
  final LowTreatmentContextController controller;

  @override
  Widget build(BuildContext context) {
    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              'Dosłodź się',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            onPressed: sheetState.isSaving
                ? null
                : () {
                    if (mode.value == LowTreatmentInputMode.quick) {
                      controller.clearMealIngredients();
                    }
                    mode.value = mode.value == LowTreatmentInputMode.quick
                        ? LowTreatmentInputMode.advanced
                        : LowTreatmentInputMode.quick;
                  },
            icon: Icon(
              mode.value == LowTreatmentInputMode.quick
                  ? Icons.tune
                  : Icons.bolt_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Zamknij',
            onPressed: sheetState.isSaving
                ? null
                : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LowTreatmentSuggestionSummary(
            suggestedCarbs: sheetState.suggestedCarbs,
            suggestedWithinMinutes: sheetState.suggestedWithinMinutes,
          ),
          const LowTreatmentRelatedRecordField(),
          const SizedBox(height: 12),
          LowTreatmentReasonSelector(
            value: sheetState.reason,
            hasAapsSuggestion: sheetState.hasAapsSuggestion,
            onChanged: controller.setReason,
          ),
          const SizedBox(height: 12),
          const LowTreatmentCarbsSummary(),
          const SizedBox(height: 12),
          if (mode.value == LowTreatmentInputMode.quick) ...[
            QuickLowTreatmentSelector(
              onSelected: controller.setQuickLowTreatmentItem,
            ),
          ] else ...[
            LowTreatmentAdvancedIngredientPicker(
              isSaving: sheetState.isSaving,
              onAddIngredient: () async {
                final mealIngredient = await showAddMealIngredientSheet(
                  context: context,
                  ref: ref,
                );
                if (mealIngredient == null) {
                  return;
                }
                controller.addMealIngredient(mealIngredient);
              },
            ),
          ],
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: sheetState.isSaving
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: !sheetState.canSave
                  ? null
                  : () async {
                      try {
                        await controller.saveCurrentDraft();
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Nie udało się zapisać dosłodzenia: $error',
                            ),
                          ),
                        );
                      }
                    },
              icon: sheetState.isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(sheetState.isSaving ? 'Zapisywanie' : 'Zapisz'),
            ),
          ),
        ],
      ),
    );
  }
}

class LowTreatmentSheetLoading extends StatelessWidget {
  const LowTreatmentSheetLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              'Dosłodź się',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Zamknij',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: const Center(child: CircularProgressIndicator()),
      actions: const SizedBox.shrink(),
    );
  }
}

class LowTreatmentSheetError extends StatelessWidget {
  const LowTreatmentSheetError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              'Dosłodź się',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Zamknij',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Text('Nie udało się przygotować dosłodzenia: $error'),
      actions: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zamknij'),
        ),
      ),
    );
  }
}

class LowTreatmentAdvancedIngredientPicker extends StatelessWidget {
  const LowTreatmentAdvancedIngredientPicker({
    super.key,
    required this.isSaving,
    required this.onAddIngredient,
  });

  final bool isSaving;
  final Future<void> Function() onAddIngredient;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: isSaving ? null : onAddIngredient,
          icon: const Icon(Icons.search),
          label: const Text('Dodaj składnik'),
        ),
        const SizedBox(height: 12),
        const LowTreatmentIngredientsList(),
      ],
    );
  }
}
