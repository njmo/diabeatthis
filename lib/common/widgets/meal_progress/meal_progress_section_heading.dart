import 'package:flutter/material.dart';

class MealProgressSectionHeading extends StatelessWidget {
  const MealProgressSectionHeading({super.key, required this.title, this.date});

  final String title;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (date != null)
            Text(
              date!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
