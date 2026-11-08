import 'package:flutter/material.dart';

class MealDecisionMealReference extends StatelessWidget {
  const MealDecisionMealReference({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
        ],
      ),
    );
  }
}
