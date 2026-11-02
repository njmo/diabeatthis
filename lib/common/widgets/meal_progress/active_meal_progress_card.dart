import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class ActiveMealProgressCard extends StatelessWidget {
  const ActiveMealProgressCard({
    super.key,
    required this.name,
    required this.status,
    required this.schedule,
    required this.steps,
    required this.actionLabel,
    required this.onAction,
    required this.onInterrupt,
    this.quickMeal = false,
    this.footer,
    this.onDelete,
    this.onEarlierFinished,
    this.onAddFood,
    this.addFoodLabel,
    this.progressAction,
  });

  final String name;
  final String status;
  final String schedule;
  final Widget steps;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onInterrupt;
  final bool quickMeal;
  final Widget? footer;
  final VoidCallback? onDelete;
  final VoidCallback? onEarlierFinished;
  final VoidCallback? onAddFood;
  final String? addFoodLabel;
  final Widget? progressAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    quickMeal ? lang.mealProgressQuickMeal : status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: lang.commonDelete,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                IconButton(
                  tooltip: lang.mealProgressInterrupt,
                  onPressed: onInterrupt,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(schedule, style: theme.textTheme.bodySmall),
                const SizedBox(height: 5),
                if (quickMeal)
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 17),
                steps,
                if (progressAction != null) progressAction!,
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: FilledButton(
                          onPressed: onAction,
                          child: Text(actionLabel, textAlign: TextAlign.center),
                        ),
                      ),
                      if (onAddFood != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: onAddFood,
                            child: Text(
                              addFoodLabel ?? lang.mealProgressAddFood,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onEarlierFinished != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      if (onEarlierFinished != null)
                        TextButton(
                          onPressed: onEarlierFinished,
                          child: Text(lang.mealEatingFinishedEarlier),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}
