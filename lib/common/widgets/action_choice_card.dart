import 'package:flutter/material.dart';

class ActionChoiceCard extends StatelessWidget {
  const ActionChoiceCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  size: 22,
                  color: onPressed == null
                      ? colors.onSurface.withValues(alpha: 0.38)
                      : colors.primary,
                ),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onPressed == null
                      ? colors.onSurface.withValues(alpha: 0.38)
                      : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
