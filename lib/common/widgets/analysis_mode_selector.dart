import 'package:flutter/material.dart';

class AnalysisModeSelector extends StatelessWidget {
  final bool advanced;
  final String basicLabel;
  final String advancedLabel;
  final ValueChanged<bool> onChanged;

  const AnalysisModeSelector({
    super.key,
    required this.advanced,
    required this.basicLabel,
    required this.advancedLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical =
            constraints.maxWidth < MediaQuery.textScalerOf(context).scale(240);
        return SegmentedButton<bool>(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          expandedInsets: vertical ? null : EdgeInsets.zero,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              label: vertical
                  ? SizedBox(
                      width: constraints.maxWidth - 64,
                      child: Text(basicLabel),
                    )
                  : Text(basicLabel),
            ),
            ButtonSegment(
              value: true,
              label: vertical
                  ? SizedBox(
                      width: constraints.maxWidth - 64,
                      child: Text(advancedLabel),
                    )
                  : Text(advancedLabel),
            ),
          ],
          selected: {advanced},
          onSelectionChanged: (selection) => onChanged(selection.single),
          style: ButtonStyle(
            side: const WidgetStatePropertyAll(BorderSide.none),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerLowest,
            ),
          ),
        );
      },
    );
  }
}
