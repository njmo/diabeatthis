import 'package:flutter/material.dart';

import 'app_icon_badge.dart';

class FabActionOption extends StatelessWidget {
  const FabActionOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.width = 210,
    this.tile = false,
    this.horizontal = false,
    this.compactCircle = false,
    this.accent,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final double width;
  final bool tile;
  final bool horizontal;
  final bool compactCircle;
  final Color? accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foregroundColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    if (compactCircle) {
      final color = enabled
          ? accent ?? theme.colorScheme.primary
          : foregroundColor;
      return Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: enabled ? 0.12 : 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: enabled ? 0.25 : 0.10),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 20,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foregroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (tile && horizontal) {
      final color = enabled
          ? accent ?? theme.colorScheme.primary
          : foregroundColor;
      return Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: color.withValues(alpha: enabled ? 0.07 : 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withValues(alpha: 0.18)),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  AppIconBadge(
                    icon: icon,
                    color: color,
                    size: 38,
                    iconSize: 22,
                    backgroundAlpha: enabled ? 0.14 : 0.05,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (tile) {
      final color = enabled
          ? accent ?? theme.colorScheme.primary
          : foregroundColor;
      return Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: color.withValues(alpha: enabled ? 0.07 : 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withValues(alpha: 0.18)),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 26, color: color),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }


    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foregroundColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
