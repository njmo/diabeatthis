import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../controllers/low_treatment_context_controller.dart';
import 'low_treatment_carbs_summary.dart';
import 'low_treatment_ingredients_list.dart';
import 'low_treatment_reason_selector.dart';
import 'low_treatment_suggestion_summary.dart';

Future<void> showLowTreatmentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => const LowTreatmentSheet(),
  );
}

class LowTreatmentSheet extends ConsumerWidget {
  const LowTreatmentSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetState = ref.watch(lowTreatmentContextControllerProvider);
    final controller = ref.read(lowTreatmentContextControllerProvider.notifier);

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
          const SizedBox(height: 12),
          LowTreatmentReasonSelector(
            value: sheetState.reason,
            hasAapsSuggestion: sheetState.hasAapsSuggestion,
            onChanged: controller.setReason,
          ),
          const SizedBox(height: 12),
          const LowTreatmentCarbsSummary(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: sheetState.isSaving
                ? null
                : () async {
                    final mealIngredient = await showAddMealIngredientSheet(
                      context: context,
                      ref: ref,
                    );
                    if (mealIngredient == null) {
                      return;
                    }
                    controller.addMealIngredient(mealIngredient);
                  },
            icon: const Icon(Icons.search),
            label: const Text('Dodaj składnik'),
          ),
          const SizedBox(height: 12),
          const LowTreatmentIngredientsList(),
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
