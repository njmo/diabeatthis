import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_formatters.dart';

class MealEatingPeriodLegend extends StatelessWidget {
  final MealDetailsData details;

  const MealEatingPeriodLegend({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final start = details.recordedEatingStartedAt;
    final end = details.recordedEatingEndedAt;
    final messages = context.lang;
    final theme = Theme.of(context);
    final label = start == null
        ? messages.mealEatingPeriodUnknown
        : end == null
        ? '${messages.mealEatingStart}: ${mealTime(start)} · ${messages.mealEatingEndUnknown}'
        : '${messages.mealEatingPeriod}: ${mealTime(start)}–${mealTime(end)} · ${formatDurationLabel(end.difference(start))}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (start != null && end != null) ...[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
