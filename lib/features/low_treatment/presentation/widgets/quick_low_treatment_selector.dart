import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/horizontal_choice_list.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../ingredients/presentation/widgets/ingredient_icon.dart';
import '../../data/providers/quick_low_treatment_item_provider.dart';
import 'quick_low_treatment_items_sheet.dart';
import 'quick_low_treatment_quantity_stepper.dart';
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lang.lowTreatmentQuickChoice,
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: enabled
                  ? () => showQuickLowTreatmentItemsSheet(context: context)
                  : null,
              child: Text(lang.ingredientEditAction),
            ),
          ],
        ),
        if (itemsAsync.isLoading) const LinearProgressIndicator(),
        if (itemsAsync.hasError)
          TextButton(
            onPressed: () => ref.invalidate(quickLowTreatmentItemsProvider),
            child: Text(lang.lowTreatmentRelationRetry),
          ),
        HorizontalChoiceList(
          itemWidth: 128,
          children: [
            for (final item in items)
              QuickLowTreatmentTile(
                item: item,
                selected: selected?.id == item.id,
                onTap: enabled
                    ? () {
                        cleared.value = false;
                        if (selectedItemId.value != item.id) {
                          multiplier.value = 1;
                        }
                        selectedItemId.value = item.id;
                      }
                    : null,
              ),
            OutlinedButton(
              onPressed: enabled
                  ? () =>
                        addQuickLowTreatmentShortcut(context: context, ref: ref)
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    items.length < maxQuickLowTreatmentItems
                        ? lang.lowTreatmentAddShortcut
                        : lang.ingredientEditAction,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 10),
          Text(
            lang.lowTreatmentAmountSection,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          SectionSurface(
            padding: const EdgeInsets.all(8),
            child: ResponsiveMetricList(
              maxColumns: 2,
              minimumWidth: 145,
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IngredientIcon(
                        assetPath: selected.ingredient.iconAssetPath,
                        size: 36,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selected.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      if (onClear != null)
                        IconButton(
                          tooltip: lang.lowTreatmentRemoveQuickChoice,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: !enabled
                              ? null
                              : () {
                                  cleared.value = true;
                                  selectedItemId.value = null;
                                  onClear!();
                                },
                        ),
                    ],
                  ),
                ),
                QuickLowTreatmentQuantityStepper(
                  value: selected.amount * multiplier.value,
                  unit:
                      selected.portion?.name ??
                      (selected.ingredient.isReference
                          ? lang.commonPortionUnit(
                              selected.amount * multiplier.value,
                            )
                          : 'g'),
                  enabled: enabled,
                  onChanged: (value) =>
                      multiplier.value = value / selected.amount,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
