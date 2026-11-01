import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

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
    final lang = context.lang;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.local_drink_rounded,
              color: colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.lowTreatmentAapsSuggestion(
                      _formatCarbs(suggestedCarbs),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (suggestedWithinMinutes > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      lang.lowTreatmentSuggestedWithin(suggestedWithinMinutes),
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
