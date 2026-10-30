import 'package:flutter/material.dart';

class DashboardDestination extends StatelessWidget {
  const DashboardDestination({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Container(
              width: selected
                  ? 60 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 1.4
                  : 48,
              height: selected
                  ? 60 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 1.4
                  : 48,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? colors.primaryContainer : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: selected ? 28 : 32),
                  if (selected) ...[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
