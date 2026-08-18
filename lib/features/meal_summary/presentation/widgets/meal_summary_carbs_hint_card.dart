import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
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
    final lang = context.lang;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final delta = calculateMealSummaryCarbsDelta(draft);
    final foregroundColor = _foregroundColor(colorScheme, delta);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor(colorScheme, delta),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon(delta), color: foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(lang, delta, addOnAlreadyReported),
                    style: textTheme.titleMedium?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _description(lang, delta, addOnAlreadyReported),
                    style: textTheme.bodySmall?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                  if (delta.roundedItemAmountDelta != 0 ||
                      delta.roundedExtraItemsCarbs != 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      lang.mealSummaryCarbsDeltaBreakdown(
                        _itemsDeltaLabel(lang, delta),
                        _formatSigned(delta.roundedItemAmountDelta),
                        delta.roundedExtraItemsCarbs,
                      ),
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

  String _title(
    AppLocalizations lang,
    MealSummaryCarbsDelta delta,
    bool addOnAlreadyReported,
  ) {
    if (delta.isPositive) {
      return lang.mealSummaryAapsPositive(delta.roundedTotal);
    }
    if (delta.isNegative) {
      return addOnAlreadyReported
          ? lang.mealSummaryAapsNegative(delta.roundedTotal)
          : lang.mealSummaryLessEaten(delta.roundedTotal);
    }
    return addOnAlreadyReported
        ? lang.mealSummaryAddOnAlreadyReported
        : lang.mealSummaryCarbsMatchPlan;
  }

  String _description(
    AppLocalizations lang,
    MealSummaryCarbsDelta delta,
    bool addOnAlreadyReported,
  ) {
    if (delta.isPositive) {
      return addOnAlreadyReported
          ? lang.mealSummaryPositiveAfterReportedAddOn
          : lang.mealSummaryPositiveDescription;
    }
    if (delta.isNegative) {
      if (addOnAlreadyReported) {
        return lang.mealSummaryNegativeAfterReportedAddOn(
          delta.roundedTotal,
          delta.roundedTotal.abs(),
        );
      }
      return lang.mealSummaryNegativeDescription(delta.roundedTotal.abs());
    }
    if (addOnAlreadyReported) {
      return lang.mealSummaryNoRepeatCarbs;
    }
    return lang.mealSummaryNoExtraCarbsNeeded;
  }

  String _itemsDeltaLabel(AppLocalizations lang, MealSummaryCarbsDelta delta) {
    if (delta.usesReportedBaseline) {
      return lang.mealSummaryChangeAfterAddOn;
    }
    return lang.mealSummaryPlanLabel;
  }

  String _formatSigned(int value) {
    if (value > 0) {
      return '+$value';
    }
    return value.toString();
  }
}
