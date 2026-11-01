import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/platform/aaps_launcher.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/models/low_treatment_sheet_state.dart';
import '../controllers/low_treatment_context_controller.dart';
import 'low_treatment_carbs_summary.dart';
import 'low_treatment_context_section.dart';
import 'low_treatment_ingredients_list.dart';
import 'low_treatment_observation_context.dart';
import 'low_treatment_suggestion_summary.dart';
import 'quick_low_treatment_selector.dart';

Future<LowTreatmentContext?> showLowTreatmentSheet(
  BuildContext context, {
  DateTime? historicalAt,
}) async {
  final launcher = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(aapsLauncherProvider);
  final saved = await showModalBottomSheet<LowTreatmentContext>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => historicalAt == null
        ? const LowTreatmentSheet()
        : ProviderScope(
            overrides: [
              lowTreatmentContextControllerProvider.overrideWith(
                () => LowTreatmentContextController(historicalAt: historicalAt),
              ),
            ],
            child: const LowTreatmentSheet(),
          ),
  );
  if (saved != null && historicalAt == null && context.mounted) {
    final result = await launcher.openAaps();
    if (result != AapsLaunchResult.opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.lang.aapsOpenFailed)));
    }
  }
  return saved;
}

class LowTreatmentSheet extends ConsumerWidget {
  const LowTreatmentSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetStateAsync = ref.watch(lowTreatmentContextControllerProvider);
    final controller = ref.read(lowTreatmentContextControllerProvider.notifier);

    return sheetStateAsync.when(
      data: (sheetState) => LowTreatmentSheetContent(
        ref: ref,
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
    required this.sheetState,
    required this.controller,
  });

  final WidgetRef ref;
  final LowTreatmentSheetState sheetState;
  final LowTreatmentContextController controller;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return KeyboardAwareBottomSheet(
      maxHeightFactor: 0.98,
      padding: const EdgeInsets.all(12),
      header: Row(
        children: [
          Expanded(
            child: Text(
              controller.historicalAt == null
                  ? lang.lowTreatmentRecordTitle
                  : '${lang.lowTreatmentRecordTitle} · ${DateFormat('dd.MM HH:mm').format(controller.historicalAt!)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: lang.commonCloseTooltip,
            onPressed: sheetState.isSaving
                ? null
                : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: sheetState.isSaving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sheetState.hasAapsSuggestion) ...[
              LowTreatmentSuggestionSummary(
                suggestedCarbs: sheetState.suggestedCarbs,
                suggestedWithinMinutes: sheetState.suggestedWithinMinutes,
              ),
              const SizedBox(height: 10),
            ],
            QuickLowTreatmentSelector(
              enabled: !sheetState.isSaving,
              onSelected: controller.setQuickLowTreatmentItem,
              onClear: controller.clearQuickIngredient,
            ),
            const SizedBox(height: 4),
            Tooltip(
              message: lang.lowTreatmentAddAnotherIngredient,
              child: OutlinedButton(
                onPressed: sheetState.isSaving
                    ? null
                    : () async {
                        final ingredient = await showAddMealIngredientSheet(
                          context: context,
                          ref: ref,
                        );
                        if (ingredient != null && context.mounted) {
                          controller.addMealIngredient(ingredient);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.standard,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(lang.lowTreatmentAddAnotherIngredient),
                  ],
                ),
              ),
            ),
            if (sheetState.mealIngredients.any(
              (entry) => !identical(entry, controller.quickIngredient),
            )) ...[
              const SizedBox(height: 10),
              LowTreatmentIngredientsList(
                ingredients: sheetState.mealIngredients
                    .where(
                      (entry) => !identical(entry, controller.quickIngredient),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            const LowTreatmentContextSection(),
            if (controller.historicalAt == null)
              const LowTreatmentObservationContext(),
          ],
        ),
      ),
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LowTreatmentCarbsSummary(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: sheetState.isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(lang.commonCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: !sheetState.canSave
                      ? null
                      : () async {
                          final saveErrorMessage = lang.lowTreatmentSaveError;
                          try {
                            final saved = await controller.saveCurrentDraft();
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).pop(saved);
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  saveErrorMessage(error.toString()),
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
                  label: Text(
                    sheetState.isSaving ? lang.commonSaving : lang.settingsSave,
                  ),
                ),
              ),
            ],
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
    final lang = context.lang;
    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              lang.lowTreatmentRecordTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: lang.commonCloseTooltip,
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
    final lang = context.lang;
    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              lang.lowTreatmentRecordTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: lang.commonCloseTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Text(lang.lowTreatmentPrepareError(error.toString())),
      actions: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lang.commonCloseTooltip),
        ),
      ),
    );
  }
}
