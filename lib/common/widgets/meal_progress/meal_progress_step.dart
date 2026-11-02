import 'package:flutter/material.dart';

class MealProgressStep extends StatelessWidget {
  const MealProgressStep({
    super.key,
    required this.label,
    required this.complete,
    required this.current,
  });

  final String label;
  final bool complete;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: complete || current
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            if (complete) ...[
              Icon(Icons.check, size: 13, color: theme.colorScheme.primary),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
