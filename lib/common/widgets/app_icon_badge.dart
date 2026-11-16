import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// Reusable squircle icon badge with soft colored background.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    this.icon,
    this.child,
    required this.color,
    this.size = AppSizes.badgeSize,
    this.iconSize = AppSizes.iconMedium,
    this.backgroundAlpha = 0.14,
    this.borderRadius,
    this.border,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final Color color;
  final double size;
  final double iconSize;
  final double backgroundAlpha;
  final BorderRadiusGeometry? borderRadius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(size * 0.32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: effectiveRadius,
        border: border ??
            Border.all(
              color: color.withValues(alpha: 0.20),
              width: 1.0,
            ),
      ),
      child: Center(
        child: child ??
            Icon(
              icon,
              size: iconSize,
              color: color,
            ),
      ),
    );
  }
}
