import 'package:flutter/material.dart';

class MealCompletionActions extends StatelessWidget {
  const MealCompletionActions({
    super.key,
    required this.primaryLabel,
    required this.primaryDescription,
    required this.secondaryLabel,
    required this.secondaryDescription,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String primaryLabel;
  final String primaryDescription;
  final String secondaryLabel;
  final String secondaryDescription;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelLarge;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget hint(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Text(text, style: hintStyle),
    );
    // Descriptions stay visible: tooltips are undiscoverable on touch screens.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            textStyle: textStyle,
          ),
          onPressed: onPrimaryPressed,
          child: Text(primaryLabel, textAlign: TextAlign.center),
        ),
        hint(primaryDescription),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            textStyle: textStyle,
          ),
          onPressed: onSecondaryPressed,
          child: Text(secondaryLabel, textAlign: TextAlign.center),
        ),
        hint(secondaryDescription),
      ],
    );
  }
}
