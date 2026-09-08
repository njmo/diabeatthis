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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Theme(
        data: base.copyWith(
          colorScheme: colors.copyWith(
            onSurface: colors.onPrimaryContainer,
            onSurfaceVariant: colors.onPrimaryContainer.withValues(alpha: 0.8),
          ),
          textTheme: base.textTheme
              .apply(
                bodyColor: colors.onPrimaryContainer,
                displayColor: colors.onPrimaryContainer,
              )
              .copyWith(
                titleLarge: base.textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                labelMedium: base.textTheme.labelMedium?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.85),
                ),
              ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: base.textTheme.titleMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: base.textTheme.bodySmall?.copyWith(
                color: colors.onPrimaryContainer.withValues(alpha: 0.8),
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
