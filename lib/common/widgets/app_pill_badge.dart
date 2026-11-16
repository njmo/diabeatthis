import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// Reusable floating pill badge for metric indicators (IOB, COB, status).
class AppPillBadge extends StatelessWidget {
  const AppPillBadge({
    super.key,
    this.icon,
    this.leading,
    this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.borderColor,
  }) : assert(icon != null || leading != null || label != null);

  final IconData? icon;
  final Widget? leading;
  final String? label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? color.withValues(alpha: 0.12);
    final stroke = borderColor ?? color.withValues(alpha: 0.22);

    final content = Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: AppSizes.iconMedium, color: color),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (label != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: AppRadius.pillBorderRadius,
      border: Border.all(color: stroke, width: 1.0),
      boxShadow: AppShadows.subtle,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorderRadius,
          child: Ink(
            decoration: decoration,
            child: content,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: decoration,
      child: content,
    );
  }
}
