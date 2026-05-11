import 'package:flutter/material.dart';

import '../models/meal_summary_draft.dart';
import '../utils/meal_summary_carbs_delta.dart';

class MealSummaryCarbsHintCard extends StatelessWidget {
  const MealSummaryCarbsHintCard({
    super.key,
    required this.draft,
    this.addOnAlreadyReported = false,
  });

  final MealSummaryDraft draft;
  final bool addOnAlreadyReported;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final delta = calculateMealSummaryCarbsDelta(draft);
    final foregroundColor = addOnAlreadyReported
        ? colorScheme.onSurfaceVariant
        : _foregroundColor(colorScheme, delta);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: addOnAlreadyReported
            ? colorScheme.surfaceContainerHighest
            : _backgroundColor(colorScheme, delta),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              addOnAlreadyReported ? Icons.check_circle_outline : _icon(delta),
              color: foregroundColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    addOnAlreadyReported
                        ? 'Dokładka już uwzględniona'
                        : _title(delta),
                    style: textTheme.titleMedium?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addOnAlreadyReported
                        ? 'Nie dopisuj ponownie tych samych węglowodanów w AAPS.'
                        : _description(delta),
                    style: textTheme.bodySmall?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                  if (!addOnAlreadyReported &&
                      (delta.roundedPlannedItemsDelta != 0 ||
                          delta.roundedExtraItemsCarbs != 0)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Plan: ${_formatSigned(delta.roundedPlannedItemsDelta)}g • Dokładka: +${delta.roundedExtraItemsCarbs}g',
                      style: textTheme.bodySmall?.copyWith(
                        color: foregroundColor,
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

  Color _backgroundColor(ColorScheme colorScheme, MealSummaryCarbsDelta delta) {
    if (delta.isPositive) {
      return colorScheme.tertiaryContainer;
    }
    if (delta.isNegative) {
      return colorScheme.errorContainer;
    }
    return colorScheme.surfaceContainerHighest;
  }

  Color _foregroundColor(ColorScheme colorScheme, MealSummaryCarbsDelta delta) {
    if (delta.isPositive) {
      return colorScheme.onTertiaryContainer;
    }
    if (delta.isNegative) {
      return colorScheme.onErrorContainer;
    }
    return colorScheme.onSurfaceVariant;
  }

  IconData _icon(MealSummaryCarbsDelta delta) {
    if (delta.isPositive) {
      return Icons.add_chart;
    }
    if (delta.isNegative) {
      return Icons.remove_circle_outline;
    }
    return Icons.check_circle_outline;
  }

  String _title(MealSummaryCarbsDelta delta) {
    if (delta.isPositive) {
      return 'Do AAPS: +${delta.roundedTotal}g węglowodanów';
    }
    if (delta.isNegative) {
      return 'Zjedzono mniej: ${delta.roundedTotal}g węglowodanów';
    }
    return 'Węglowodany zgodne z planem';
  }

  String _description(MealSummaryCarbsDelta delta) {
    if (delta.isPositive) {
      return 'Tę wartość wpisz jako dodatkowe węglowodany. AAPS policzy insulinę według profilu.';
    }
    if (delta.isNegative) {
      return 'Brakuje około ${delta.roundedTotal.abs()}g względem planu. Jeśli bolus był na pełny plan, rozważ dojedzenie tej ilości węglowodanów.';
    }
    return 'Nie trzeba dopisywać dodatkowych węglowodanów.';
  }

  String _formatSigned(int value) {
    if (value > 0) {
      return '+$value';
    }
    return value.toString();
  }
}
