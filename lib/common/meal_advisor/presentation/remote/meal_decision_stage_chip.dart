import 'package:flutter/material.dart';

class MealDecisionStageChip extends StatelessWidget {
  const MealDecisionStageChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color:
          Theme.of(context).brightness == Brightness.light &&
              color.computeLuminance() > .3
          ? Theme.of(context).colorScheme.inverseSurface
          : color.withValues(alpha: .10),
      border: Border.all(color: color.withValues(alpha: .45)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
