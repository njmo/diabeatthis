import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../data/providers/quick_low_treatment_item_provider.dart';
import '../formatters/quick_low_treatment_item_formatter.dart';
import 'quick_low_treatment_items_sheet.dart';

typedef QuickLowTreatmentItemSelected =
    void Function(QuickLowTreatmentItem item, int quantity);

class QuickLowTreatmentSelector extends HookConsumerWidget {
  const QuickLowTreatmentSelector({super.key, required this.onSelected});

  final QuickLowTreatmentItemSelected onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(quickLowTreatmentItemsProvider);
    final selectedItemId = useState<int?>(null);
    final quantity = useState(1);
    final items = itemsAsync.asData?.value ?? const <QuickLowTreatmentItem>[];
    final selectedItem =
        _quickItemById(items, selectedItemId.value) ??
        (items.isEmpty ? null : items.first);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || selectedItem == null) {
          return;
        }
        if (selectedItemId.value != selectedItem.id) {
          selectedItemId.value = selectedItem.id;
        }
        onSelected(selectedItem, quantity.value);
      });
      return null;
    }, [selectedItem, quantity.value]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: QuickLowTreatmentDropdown(
            items: items,
            isLoading: itemsAsync.isLoading && items.isEmpty,
            selectedItem: selectedItem,
            onChanged: (item) {
              selectedItemId.value = item.id;
            },
          ),
        ),
        const SizedBox(width: 8),
        QuickLowTreatmentQuantityStepper(
          value: quantity.value,
          enabled: selectedItem != null,
          onChanged: (value) => quantity.value = value,
        ),
        const SizedBox(width: 8),
        QuickLowTreatmentSettingsButton(
          onPressed: () => showQuickLowTreatmentItemsSheet(context: context),
        ),
      ],
    );
  }
}

class QuickLowTreatmentDropdown extends StatelessWidget {
  const QuickLowTreatmentDropdown({
    super.key,
    required this.items,
    required this.isLoading,
    required this.selectedItem,
    required this.onChanged,
  });

  final List<QuickLowTreatmentItem> items;
  final bool isLoading;
  final QuickLowTreatmentItem? selectedItem;
  final ValueChanged<QuickLowTreatmentItem> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
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
            child: item == null
                ? Text(
                    isLoading ? lang.commonLoading : lang.quickLowTreatmentAdd,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : QuickLowTreatmentSelectedItem(item: item),
          ),
        ),
      ),
    );
  }
}

class QuickLowTreatmentQuantityStepper extends StatelessWidget {
  const QuickLowTreatmentQuantityStepper({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canDecrease = enabled && value > 1;

    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: canDecrease ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 20, height: 40),
            ),
            SizedBox(
              width: 18,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: enabled ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 20, height: 40),
            ),
          ],
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
      width: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.settings_input_component_outlined),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

QuickLowTreatmentItem? _quickItemById(
  List<QuickLowTreatmentItem> items,
  int? id,
) {
  if (id == null) {
    return null;
  }
  for (final item in items) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}
