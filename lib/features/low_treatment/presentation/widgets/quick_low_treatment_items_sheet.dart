import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/mappers/quick_low_treatment_item_mapper.dart';
import '../../data/models/quick_low_treatment_items_state.dart';
import '../../data/models/quick_low_treatment_slot.dart';
import '../controllers/quick_low_treatment_items_controller.dart';
import '../formatters/quick_low_treatment_item_formatter.dart';

Future<void> showQuickLowTreatmentItemsSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => const QuickLowTreatmentItemsSheet(),
  );
}

class QuickLowTreatmentItemsSheet extends ConsumerWidget {
  const QuickLowTreatmentItemsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final asyncState = ref.watch(quickLowTreatmentItemsControllerProvider);
    final state =
        asyncState.value ??
        QuickLowTreatmentItemsState(slots: buildQuickLowTreatmentSlots([]));
    final isBusy = asyncState.isLoading || state.isSaving;
    final controller = ref.read(
      quickLowTreatmentItemsControllerProvider.notifier,
    );

    return KeyboardAwareBottomSheet(
      header: BottomSheetStepHeader(
        title: lang.quickLowTreatmentItemsTitle,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SizedBox(
        height: 456,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: state.slots.length,
          onReorderItem: (oldIndex, newIndex) async {
            final targetIndex = newIndex.clamp(0, state.slots.length - 1);
            if (oldIndex == targetIndex) {
              return;
            }

            await controller.swapSlots(
              source: state.slots[oldIndex],
              target: state.slots[targetIndex],
            );
          },
          itemBuilder: (context, index) {
            final slot = state.slots[index];
            final item = slot.item;
            final key = ValueKey('quick-low-treatment-slot-${slot.slot}');

            if (item == null) {
              return QuickLowTreatmentEmptySlotCard(
                key: key,
                isSaving: isBusy,
                onAdd: () async {
                  await _addOrEditQuickLowTreatmentItem(
                    context: context,
                    ref: ref,
                    slot: slot,
                  );
                },
              );
            }

            final colorScheme = Theme.of(context).colorScheme;

            return ReorderableDelayedDragStartListener(
              key: key,
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: Text('${slot.slot}'),
                    ),
                    title: Text(item.name),
                    subtitle: Text(formatQuickLowTreatmentItemDetails(item)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: isBusy
                              ? null
                              : () async {
                                  await _addOrEditQuickLowTreatmentItem(
                                    context: context,
                                    ref: ref,
                                    slot: slot,
                                    initialDraft: item.toMealIngredientDraft(),
                                  );
                                },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: isBusy
                              ? null
                              : () async {
                                  await controller.deleteItem(item);
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                        const Icon(Icons.drag_indicator),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: FilledButton.icon(
        onPressed: isBusy ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.check),
        label: Text(lang.commonDone),
      ),
    );
  }
}

Future<void> _addOrEditQuickLowTreatmentItem({
  required BuildContext context,
  required WidgetRef ref,
  required QuickLowTreatmentSlot slot,
  MealIngredientsDraft? initialDraft,
}) async {
  final mealIngredient = await showAddMealIngredientSheet(
    context: context,
    ref: ref,
    initialDraft: initialDraft,
  );
  if (mealIngredient == null) {
    return;
  }

  try {
    await ref
        .read(quickLowTreatmentItemsControllerProvider.notifier)
        .upsertSlot(
          slot: slot.slot,
          mealIngredient: mealIngredient,
          existingItem: slot.item,
        );
  } catch (error) {
    final errorMessage = _quickItemSaveErrorMessage(error);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage)));
  }
}

String _quickItemSaveErrorMessage(Object error) {
  if (error is ArgumentError) {
    final message = error.message;
    if (message != null) {
      return message.toString();
    }
  }
  return lang.quickLowTreatmentSaveError;
}

class QuickLowTreatmentEmptySlotCard extends StatelessWidget {
  const QuickLowTreatmentEmptySlotCard({
    super.key,
    required this.isSaving,
    required this.onAdd,
  });

  final bool isSaving;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isSaving
              ? null
              : () async {
                  await onAdd();
                },
          child: SizedBox(
            height: 72,
            child: Center(
              child: Icon(
                Icons.add,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
