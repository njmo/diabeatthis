import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class NutritionMetricTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color? iconColor;
  final String label;
  final String value;
  final bool emphasized;
  final Color? accentColor;
  final double iconSize;
  final double iconSpacing;

  const NutritionMetricTile({
    this.icon,
    this.leading,
    this.iconColor,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.accentColor,
    this.iconSize = 24,
    this.iconSpacing = 10,
    super.key,
  }) : assert(icon != null || leading != null);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveColor = accentColor ?? iconColor;
    final backgroundColor = accentColor?.withValues(alpha: 0.12) ??
        (emphasized
            ? colorScheme.primaryContainer
            : (isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC)));

    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final effectiveIconColor = iconColor ??
        (emphasized
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(
                size: iconSize,
                color: effectiveIconColor,
              ),
              child: leading ?? Icon(icon),
            ),
            SizedBox(width: iconSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: (accentColor == null
                            ? textTheme.titleMedium
                            : textTheme.headlineSmall)
                        ?.copyWith(
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

