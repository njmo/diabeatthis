import 'package:flutter/material.dart';

class ValueChangeRow extends StatelessWidget {
  const ValueChangeRow({
    super.key,
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                before,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text(
                after,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
