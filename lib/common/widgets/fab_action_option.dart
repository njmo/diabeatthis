import 'package:flutter/material.dart';

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
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final double width;
  final bool tile;
  final bool horizontal;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foregroundColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

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
              constraints: BoxConstraints(minHeight: horizontal ? 56 : 80),
              padding: const EdgeInsets.all(10),
              child: horizontal
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 26, color: color),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: foregroundColor,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
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
