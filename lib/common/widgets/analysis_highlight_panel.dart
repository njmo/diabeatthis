import 'package:flutter/material.dart';

class AnalysisHighlightPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const AnalysisHighlightPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final colors = base.colorScheme;
    final isDark = base.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? colors.primaryContainer.withValues(alpha: 0.30)
        : colors.surface;
    final borderColor = isDark
        ? colors.primary.withValues(alpha: 0.25)
        : colors.outlineVariant.withValues(alpha: 0.55);
    final textMain = isDark ? colors.onPrimaryContainer : colors.onSurface;
    final textMuted = isDark
        ? colors.onPrimaryContainer.withValues(alpha: 0.8)
        : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: base.copyWith(
          colorScheme: colors.copyWith(
            onSurface: textMain,
            onSurfaceVariant: textMuted,
          ),
          textTheme: base.textTheme
              .apply(
                bodyColor: textMain,
                displayColor: textMain,
              )
              .copyWith(
                titleLarge: base.textTheme.headlineMedium?.copyWith(
                  color: textMain,
                  fontWeight: FontWeight.w600,
                ),
                labelMedium: base.textTheme.labelMedium?.copyWith(
                  color: textMuted,
                ),
              ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: base.textTheme.titleMedium?.copyWith(
                color: textMain,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: base.textTheme.bodySmall?.copyWith(
                color: textMuted,
              ),
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
