import 'package:flutter/material.dart';

class AnalysisTimelineRow extends StatelessWidget {
  final String time;
  final String title;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const AnalysisTimelineRow({
    super.key,
    required this.time,
    required this.title,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: selected ? theme.colorScheme.secondaryContainer : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(48),
              child: Text(time, style: theme.textTheme.labelMedium),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 14),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(title, style: theme.textTheme.titleSmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
