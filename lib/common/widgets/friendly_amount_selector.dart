import 'package:flutter/material.dart';

import '../l10n/language.dart';
import 'amount_entry_dialog.dart';

class FriendlyAmountOption {
  const FriendlyAmountOption({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final double value;
  final IconData? icon;
}

class FriendlyAmountSelector extends StatelessWidget {
  const FriendlyAmountSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.valueLabel,
    this.min = 0,
    this.max,
    this.step = 0.5,
  });

  final double value;
  final List<FriendlyAmountOption> options;
  final ValueChanged<double> onChanged;
  final String Function(double value) valueLabel;
  final double min;
  final double? max;
  final double step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedValue = _normalize(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                IconButton.filledTonal(
                  padding: const EdgeInsets.all(15),
                  tooltip: context.lang.commonLessTooltip,
                  onPressed: normalizedValue <= min
                      ? null
                      : () => onChanged(_normalize(normalizedValue - step)),
                  icon: Text(_stepLabel(-step), style: TextStyle(fontSize: 20)),
                ),
                IconButton.filledTonal(
                  tooltip: context.lang.commonLessTooltip,
                  onPressed: normalizedValue <= min
                      ? null
                      : () => onChanged(_normalize(normalizedValue - 1)),
                  icon: Text(_stepLabel(-1)),
                ),
                Expanded(
                  child: Tooltip(
                    message: context.lang.amountEntryTitle,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        foregroundColor: colorScheme.onSurface,
                        textStyle: Theme.of(context).textTheme.titleLarge,
                      ),
                      onPressed: () async {
                        final entered = await showDialog<double>(
                          context: context,
                          builder: (_) => AmountEntryDialog(
                            value: normalizedValue,
                            min: min,
                            max: max,
                          ),
                        );
                        if (context.mounted && entered != null) {
                          onChanged(_normalize(entered));
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              valueLabel(normalizedValue),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: context.lang.commonMoreTooltip,
                  onPressed: max != null && normalizedValue >= max!
                      ? null
                      : () => onChanged(_normalize(normalizedValue + 1)),
                  icon: Text(_stepLabel(1)),
                ),
                IconButton.filledTonal(
                  padding: const EdgeInsets.all(15),
                  tooltip: context.lang.commonMoreTooltip,
                  onPressed: max != null && normalizedValue >= max!
                      ? null
                      : () => onChanged(_normalize(normalizedValue + step)),
                  icon: Text(_stepLabel(step), style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                selected: _isSelected(normalizedValue, option.value),
                avatar: option.icon == null
                    ? null
                    : Icon(option.icon, size: 18),
                label: Text(option.label),
                onSelected: (_) => onChanged(_normalize(option.value)),
              ),
          ],
        ),
      ],
    );
  }

  double _normalize(double rawValue) {
    final rounded = (rawValue * 10).round() / 10;
    final clampedToMin = rounded < min ? min : rounded;
    final clampedToMax = max == null || clampedToMin <= max!
        ? clampedToMin
        : max!;
    return double.parse(clampedToMax.toStringAsFixed(1));
  }

  bool _isSelected(double current, double option) {
    return (current - _normalize(option)).abs() < 0.05;
  }

  String _stepLabel(double rawStep) {
    final sign = rawStep > 0 ? '+' : '-';
    final absolute = rawStep.abs();
    final formatted = absolute % 1 == 0
        ? absolute.toStringAsFixed(0)
        : absolute.toStringAsFixed(1).replaceAll('.', ',');
    return '$sign$formatted';
  }
}
