import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../data/providers/quick_low_treatment_item_provider.dart';
import 'quick_low_treatment_items_sheet.dart';
import 'quick_low_treatment_selection.dart';
import 'quick_low_treatment_tile.dart';

export 'quick_low_treatment_quantity_stepper.dart';

typedef QuickLowTreatmentItemSelected =
    void Function(QuickLowTreatmentItem item, double quantity);

class QuickLowTreatmentSelector extends HookConsumerWidget {
  const QuickLowTreatmentSelector({
    super.key,
    required this.onSelected,
    this.onClear,
    this.enabled = true,
  });

  final QuickLowTreatmentItemSelected onSelected;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(quickLowTreatmentItemsProvider);
    final selectedItemId = useState<int?>(null);
    final multiplier = useState(1.0);
    final cleared = useState(false);
    final items = itemsAsync.asData?.value ?? const <QuickLowTreatmentItem>[];
    final matches = items.where((item) => item.id == selectedItemId.value);
    final selected =
        matches.firstOrNull ??
        (selectedItemId.value == null && !cleared.value
            ? items.firstOrNull
            : null);
    final countsSavedAmount =
        selected != null &&
        selected.portion == null &&
        !selected.ingredient.isReference;
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !enabled) return;
        if (selected == null) {
          if (selectedItemId.value != null) {
            selectedItemId.value = null;
            cleared.value = true;
            onClear?.call();
          }
          return;
        }
        selectedItemId.value = selected.id;
        onSelected(selected, multiplier.value);
      });
      return null;
    }, [selected, multiplier.value, enabled]);
    final lang = context.lang;
    final actualAmount = selected == null
        ? 0.0
        : selected.amount * multiplier.value;
    return QuickLowTreatmentSelection(
      enabled: enabled,
      actionLabel: items.length < maxQuickLowTreatmentItems
          ? lang.lowTreatmentAddShortcut
          : lang.ingredientEditAction,
      onAction: () => addQuickLowTreatmentShortcut(context: context, ref: ref),
      onEdit: () => showQuickLowTreatmentItemsSheet(context: context),
      status: itemsAsync.isLoading
          ? const LinearProgressIndicator()
          : itemsAsync.hasError
          ? TextButton(
              onPressed: () => ref.invalidate(quickLowTreatmentItemsProvider),
              child: Text(lang.lowTreatmentRelationRetry),
            )
          : null,
      choices: [
        for (final item in items)
          QuickLowTreatmentTile(
            name: item.name,
            iconAssetPath: item.ingredient.iconAssetPath,
            selected: selected?.id == item.id,
            onTap: enabled
                ? () {
                    cleared.value = false;
                    if (selectedItemId.value != item.id) multiplier.value = 1;
                    selectedItemId.value = item.id;
                  }
                : null,
          ),
      ],
      selected: selected == null
          ? null
          : QuickLowTreatmentAmount(
              name: selected.name,
              iconAssetPath: selected.ingredient.iconAssetPath,
              subtitle: countsSavedAmount
                  ? '${NumberFormat('0.############', lang.localeName).format(selected.amount)} g'
                  : null,
              quantity: countsSavedAmount ? multiplier.value : actualAmount,
              unit:
                  selected.portion?.name ??
                  (selected.ingredient.isReference
                      ? lang.commonPortionUnit(actualAmount)
                      : '×'),
              onChanged: (value) => multiplier.value = countsSavedAmount
                  ? value
                  : value / selected.amount,
              onClear: onClear == null
                  ? null
                  : () {
                      cleared.value = true;
                      selectedItemId.value = null;
                      onClear!();
                    },
            ),
    );
  }
}
