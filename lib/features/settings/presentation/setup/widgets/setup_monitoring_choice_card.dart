import 'package:flutter/material.dart';

import 'setup_icon_bubble.dart';

class SetupMonitoringChoiceCard extends StatelessWidget {
  const SetupMonitoringChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.chips,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onSelected;
  final Widget? chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderRadius = BorderRadius.circular(20);
    return Semantics(
      enabled: onSelected != null,
      selected: selected,
      button: true,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SetupIconBubble(icon: icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? colors.primary : colors.outline,
                    ),
                  ],
                ),
                if (chips != null) ...[const SizedBox(height: 12), chips!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
