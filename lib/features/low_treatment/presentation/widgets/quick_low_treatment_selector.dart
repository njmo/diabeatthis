import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../core/domain/model/ingredient.dart';
import '../../../../core/domain/model/portion.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';

const List<QuickLowTreatmentItem> quickLowTreatmentFakeCatalog = [
  QuickLowTreatmentItem(
    id: 1,
    name: 'Dextro',
    ingredient: Ingredient(
      id: 1,
      name: 'Dextro',
      carbsPer100g: 90,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 1,
      isReference: false,
    ),
    portion: Portion(id: 1, name: 'cukierek', unitHint: 'szt.'),
    amount: 1,
    sortOrder: 1,
    isActive: true,
    gramsPerPortion: 3,
  ),
  QuickLowTreatmentItem(
    id: 2,
    name: 'Sok jabłkowy',
    ingredient: Ingredient(
      id: 2,
      name: 'Sok jabłkowy',
      carbsPer100g: 11,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 0.8,
      isReference: false,
    ),
    portion: Portion(id: 2, name: 'porcja', unitHint: 'ml'),
    amount: 1,
    sortOrder: 2,
    isActive: true,
    gramsPerPortion: 100,
  ),
  QuickLowTreatmentItem(
    id: 3,
    name: 'Żel',
    ingredient: Ingredient(
      id: 3,
      name: 'Żel',
      carbsPer100g: 60,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 0.75,
      isReference: false,
    ),
    portion: Portion(id: 3, name: 'saszetka', unitHint: 'szt.'),
    amount: 1,
    sortOrder: 3,
    isActive: true,
    gramsPerPortion: 25,
  ),
  QuickLowTreatmentItem(
    id: 4,
    name: 'Glukoza',
    ingredient: Ingredient(
      id: 4,
      name: 'Glukoza',
      carbsPer100g: 100,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 1,
      isReference: false,
    ),
    portion: null,
    amount: 10,
    sortOrder: 4,
    isActive: true,
    gramsPerPortion: null,
  ),
  QuickLowTreatmentItem(
    id: 5,
    name: 'Cukier',
    ingredient: Ingredient(
      id: 5,
      name: 'Cukier',
      carbsPer100g: 100,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 1,
      isReference: false,
    ),
    portion: Portion(id: 5, name: 'łyżeczka', unitHint: 'szt.'),
    amount: 1,
    sortOrder: 5,
    isActive: true,
    gramsPerPortion: 5,
  ),
  QuickLowTreatmentItem(
    id: 6,
    name: 'Cola',
    ingredient: Ingredient(
      id: 6,
      name: 'Cola',
      carbsPer100g: 10.6,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 0.75,
      isReference: false,
    ),
    portion: Portion(id: 6, name: 'porcja', unitHint: 'ml'),
    amount: 1,
    sortOrder: 6,
    isActive: true,
    gramsPerPortion: 100,
  ),
];

class QuickLowTreatmentSelector extends HookWidget {
  const QuickLowTreatmentSelector({super.key, required this.onSelected});

  final ValueChanged<QuickLowTreatmentItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final slots = useState(initialQuickLowTreatmentSlots());
    final selectedItemId = useState<int?>(slots.value.first.item?.id);
    final activeSlots = slots.value.where((slot) => slot.item != null).toList();
    final selectedItem = quickItemById(slots.value, selectedItemId.value);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && selectedItem != null) {
          onSelected(selectedItem);
        }
      });
      return null;
    }, const []);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: QuickLowTreatmentDropdown(
            items: activeSlots
                .map((slot) => slot.item!)
                .toList(growable: false),
            selectedItem: selectedItem,
            onChanged: (item) {
              selectedItemId.value = item.id;
              onSelected(item);
            },
          ),
        ),
        const SizedBox(width: 8),
        QuickLowTreatmentSettingsButton(
          onPressed: () async {
            final updatedSlots = await showQuickLowTreatmentItemsSheet(
              context: context,
              initialSlots: slots.value,
            );
            if (updatedSlots == null) {
              return;
            }

            slots.value = updatedSlots;
            if (!updatedSlots.any(
              (slot) => slot.item?.id == selectedItemId.value,
            )) {
              final updatedActiveSlots = updatedSlots.where(
                (slot) => slot.item != null,
              );
              selectedItemId.value = updatedActiveSlots.isEmpty
                  ? null
                  : updatedActiveSlots.first.item!.id;
            }

            final item = quickItemById(updatedSlots, selectedItemId.value);
            if (item != null) {
              onSelected(item);
            }
          },
        ),
      ],
    );
  }
}

class QuickLowTreatmentDropdown extends StatelessWidget {
  const QuickLowTreatmentDropdown({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
  });

  final List<QuickLowTreatmentItem> items;
  final QuickLowTreatmentItem? selectedItem;
  final ValueChanged<QuickLowTreatmentItem> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = selectedItem;

    return PopupMenuButton<QuickLowTreatmentItem>(
      enabled: items.isNotEmpty,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<QuickLowTreatmentItem>(
            value: item,
            child: QuickLowTreatmentMenuItem(item: item),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: item == null
                      ? Text(
                          'Brak szybkich dosłodzeń',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        )
                      : QuickLowTreatmentSelectedItem(item: item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickLowTreatmentSelectedItem extends StatelessWidget {
  const QuickLowTreatmentSelectedItem({super.key, required this.item});

  final QuickLowTreatmentItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge,
        ),
        Text(
          formatQuickLowTreatmentItemDetails(item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class QuickLowTreatmentMenuItem extends StatelessWidget {
  const QuickLowTreatmentMenuItem({super.key, required this.item});

  final QuickLowTreatmentItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          Text(
            formatQuickLowTreatmentItemDetails(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class QuickLowTreatmentSettingsButton extends StatelessWidget {
  const QuickLowTreatmentSettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 56,
      child: Center(
        child: SizedBox.square(
          dimension: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: onPressed,
              icon: const Icon(Icons.settings_input_component_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

Future<List<QuickLowTreatmentUiSlot>?> showQuickLowTreatmentItemsSheet({
  required BuildContext context,
  required List<QuickLowTreatmentUiSlot> initialSlots,
}) {
  return showModalBottomSheet<List<QuickLowTreatmentUiSlot>>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => QuickLowTreatmentItemsSheet(initialSlots: initialSlots),
  );
}

class QuickLowTreatmentItemsSheet extends HookWidget {
  const QuickLowTreatmentItemsSheet({super.key, required this.initialSlots});

  final List<QuickLowTreatmentUiSlot> initialSlots;

  @override
  Widget build(BuildContext context) {
    final slots = useState([...initialSlots]);

    void swapSlots(int oldIndex, int newIndex) {
      final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      if (oldIndex == targetIndex) {
        return;
      }

      final updatedSlots = [...slots.value];
      final source = updatedSlots[oldIndex];
      final target = updatedSlots[targetIndex];
      updatedSlots[oldIndex] = source.copyWith(item: target.item);
      updatedSlots[targetIndex] = target.copyWith(item: source.item);
      slots.value = updatedSlots;
    }

    void assignFakeItem(int index) {
      final usedIds = slots.value
          .map((slot) => slot.item?.id)
          .whereType<int>()
          .toSet();
      final candidate = quickLowTreatmentFakeCatalog.firstWhere(
        (item) => !usedIds.contains(item.id),
        orElse: () => quickLowTreatmentFakeCatalog.first,
      );
      final updatedSlots = [...slots.value];
      updatedSlots[index] = updatedSlots[index].copyWith(
        item: candidate.copyWith(sortOrder: updatedSlots[index].slot),
      );
      slots.value = updatedSlots;
    }

    void clearSlot(int index) {
      final updatedSlots = [...slots.value];
      updatedSlots[index] = updatedSlots[index].copyWith(item: null);
      slots.value = updatedSlots;
    }

    return KeyboardAwareBottomSheet(
      header: BottomSheetStepHeader(
        title: 'Szybkie dosłodzenia',
        onBack: () => Navigator.of(context).pop(slots.value),
      ),
      body: SizedBox(
        height: 456,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: slots.value.length,
          onReorderItem: swapSlots,
          itemBuilder: (context, index) {
            final slot = slots.value[index];
            return QuickLowTreatmentSlotCard(
              key: ValueKey('quick-low-treatment-slot-${slot.slot}'),
              slot: slot,
              index: index,
              onAdd: () => assignFakeItem(index),
              onRemove: slot.item == null ? null : () => clearSlot(index),
            );
          },
        ),
      ),
      actions: FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(slots.value),
        icon: const Icon(Icons.check),
        label: const Text('Gotowe'),
      ),
    );
  }
}

class QuickLowTreatmentSlotCard extends StatelessWidget {
  const QuickLowTreatmentSlotCard({
    super.key,
    required this.slot,
    required this.index,
    required this.onAdd,
    required this.onRemove,
  });

  final QuickLowTreatmentUiSlot slot;
  final int index;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final item = slot.item;

    if (item == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onAdd,
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

    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: QuickLowTreatmentSlotNumber(slot: slot.slot),
            title: Text(item.name),
            subtitle: Text(formatQuickLowTreatmentItemDetails(item)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Usuń',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
                const Icon(Icons.drag_indicator),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickLowTreatmentSlotNumber extends StatelessWidget {
  const QuickLowTreatmentSlotNumber({super.key, required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Text('$slot'),
    );
  }
}

class QuickLowTreatmentUiSlot {
  const QuickLowTreatmentUiSlot({required this.slot, this.item});

  final int slot;
  final QuickLowTreatmentItem? item;

  QuickLowTreatmentUiSlot copyWith({QuickLowTreatmentItem? item}) {
    return QuickLowTreatmentUiSlot(slot: slot, item: item);
  }
}

List<QuickLowTreatmentUiSlot> initialQuickLowTreatmentSlots() {
  return [
    for (var index = 0; index < maxQuickLowTreatmentItems; index++)
      QuickLowTreatmentUiSlot(
        slot: index + 1,
        item: quickLowTreatmentFakeCatalog.length > index
            ? quickLowTreatmentFakeCatalog[index]
            : null,
      ),
  ];
}

QuickLowTreatmentItem? quickItemById(
  List<QuickLowTreatmentUiSlot> slots,
  int? id,
) {
  if (id == null) {
    return null;
  }
  final matchingSlots = slots.where((slot) => slot.item?.id == id);
  if (matchingSlots.isEmpty) {
    return null;
  }
  return matchingSlots.first.item;
}

String formatQuickLowTreatmentItemDetails(QuickLowTreatmentItem item) {
  final carbs = calculateQuickLowTreatmentCarbs(item).round();
  final amount = formatQuickLowTreatmentAmount(item.amount);

  if (item.portion == null) {
    return '$amount g • $carbs g WW';
  }

  return '$amount x ${item.portion!.name} • $carbs g WW';
}

double calculateQuickLowTreatmentCarbs(QuickLowTreatmentItem item) {
  final grams = item.portion == null
      ? item.amount
      : item.amount * (item.gramsPerPortion ?? 0);
  return grams * item.ingredient.carbsPer100g / 100;
}

String formatQuickLowTreatmentAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
