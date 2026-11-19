import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/horizontal_choice_list.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../../ingredients/presentation/widgets/ingredient_icon.dart';
import 'quick_low_treatment_quantity_stepper.dart';

class QuickLowTreatmentSelection extends StatelessWidget {
  const QuickLowTreatmentSelection({
    super.key,
    required this.choices,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.onEdit,
    this.status,
    this.selected,
    this.enabled = true,
  });

  final List<Widget> choices;
  final String actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final VoidCallback? onEdit;
  final Widget? status;
  final QuickLowTreatmentAmount? selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final theme = Theme.of(context);
    final amount = selected;
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
            if (onEdit != null)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                onPressed: enabled ? onEdit : null,
                child: Text(lang.ingredientEditAction),
              ),
          ],
        ),
        if (status != null) status!,
        HorizontalChoiceList(
          itemWidth: 128,
          children: [
            ...choices,
            if (onAction != null)
              OutlinedButton(
                onPressed: enabled ? onAction : null,
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
                    Icon(actionIcon, size: 28),
                    const SizedBox(height: 8),
                    Text(actionLabel, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
        if (amount != null) ...[
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
                      IngredientIcon(assetPath: amount.iconAssetPath, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              amount.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            if (amount.subtitle != null)
                              Text(
                                amount.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ),
                      if (amount.onClear != null)
                        IconButton(
                          tooltip: lang.lowTreatmentRemoveQuickChoice,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: enabled ? amount.onClear : null,
                        ),
                    ],
                  ),
                ),
                QuickLowTreatmentQuantityStepper(
                  value: amount.quantity,
                  unit: amount.unit,
                  enabled: enabled,
                  onChanged: amount.onChanged,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class QuickLowTreatmentAmount {
  const QuickLowTreatmentAmount({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.onChanged,
    this.iconAssetPath,
    this.subtitle,
    this.onClear,
  });

  final String name;
  final double quantity;
  final String unit;
  final ValueChanged<double> onChanged;
  final String? iconAssetPath;
  final String? subtitle;
  final VoidCallback? onClear;
}
