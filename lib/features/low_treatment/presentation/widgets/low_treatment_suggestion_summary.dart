import 'package:flutter/material.dart';

class LowTreatmentSuggestionSummary extends StatelessWidget {
  const LowTreatmentSuggestionSummary({
    super.key,
    required this.suggestedCarbs,
    required this.suggestedWithinMinutes,
  });

  final double suggestedCarbs;
  final int suggestedWithinMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSuggestion = suggestedCarbs > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: hasSuggestion
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.local_drink_outlined,
              color: hasSuggestion
                  ? colorScheme.onTertiaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSuggestion
                        ? 'Sugestia AAPS: ${_formatCarbs(suggestedCarbs)} g'
                        : 'Brak aktywnej sugestii AAPS',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: hasSuggestion
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasSuggestion && suggestedWithinMinutes > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'W ciągu $suggestedWithinMinutes min',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCarbs(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}
