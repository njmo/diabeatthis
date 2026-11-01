import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/amount_entry_dialog.dart';

class QuickLowTreatmentQuantityStepper extends StatelessWidget {
  const QuickLowTreatmentQuantityStepper({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.unit,
  });

  final double value;
  final String? unit;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = NumberFormat('0.0', context.lang.localeName).format(0.5);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.lang.quickLowTreatmentDecrease,
            onPressed: enabled && value > 0.5
                ? () => onChanged((value - 0.5).clamp(0.5, double.infinity))
                : null,
            icon: FittedBox(
              child: Text(
                '−$step',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: enabled && value > 0.5
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
              ),
              onPressed: !enabled
                  ? null
                  : () async {
                      final entered = await showDialog<double>(
                        context: context,
                        builder: (_) =>
                            AmountEntryDialog(value: value, min: 0.5),
                      );
                      if (entered != null && context.mounted) {
                        onChanged(entered);
                      }
                    },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: NumberFormat(
                          '0.############',
                          context.lang.localeName,
                        ).format(value),
                      ),
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: context.lang.quickLowTreatmentIncrease,
            onPressed: enabled ? () => onChanged(value + 0.5) : null,
            icon: FittedBox(
              child: Text(
                '+$step',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
