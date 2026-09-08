import 'package:flutter/material.dart';

class AnalysisMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final int labelLines;
  final IconData? icon;

  const AnalysisMetric({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.labelLines = 1,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: labelLines <= 1
                ? 0
                : MediaQuery.textScalerOf(context).scale(16) * labelLines,
          ),
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
