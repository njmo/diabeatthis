import 'package:flutter/material.dart';

/// Dashboard metadata, aligned with the meal title rather than a separate card.
class MealDecisionCompactStatus extends StatelessWidget {
  const MealDecisionCompactStatus({
    super.key,
    required this.name,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String name, label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Stack(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(icon, size: 10, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Tooltip(
            message: '$name · $label',
            child: Text(
              '$name · $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    ),
  );
}
