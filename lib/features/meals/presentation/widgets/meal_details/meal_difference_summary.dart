import 'package:flutter/material.dart';

class MealDifferenceSummary extends StatelessWidget {
  const MealDifferenceSummary({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.different = false,
  });
  final String title;
  final String value;
  final IconData icon;
  final bool different;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: different
          ? colors.tertiaryContainer
          : colors.primaryContainer.withValues(alpha: .35),
      child: ListTile(
        leading: Icon(
          icon,
          color: different ? colors.onTertiaryContainer : colors.primary,
        ),
        title: Text(title, style: Theme.of(context).textTheme.labelLarge),
        subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
