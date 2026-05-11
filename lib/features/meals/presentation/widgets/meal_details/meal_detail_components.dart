import 'package:flutter/material.dart';

class MealSectionTile extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const MealSectionTile({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: children,
      ),
    );
  }
}

class MealInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const MealInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class MealIconInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const MealIconInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class MealSummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const MealSummaryCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class MealSmallBadge extends StatelessWidget {
  final String label;

  const MealSmallBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
