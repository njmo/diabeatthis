import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/analysis_timeline_row.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';

class MealRecordedActions extends StatelessWidget {
  const MealRecordedActions({super.key, required this.details});
  final MealDetailsData details;

  @override
  Widget build(BuildContext context) => SummaryDetailCard(
    title: context.lang.mealRecordedActionsTitle,
    icon: Icons.timeline_rounded,
    child: Column(
      children: [
        for (final entry in details.statusTimeline)
          AnalysisTimelineRow(
            time: mealTime(entry.timestamp),
            title: mealStatusLabel(entry.status),
            detail: mealDateTime(entry.timestamp),
            icon: mealStatusIcon(entry.status),
            selected: entry.isCurrent,
          ),
      ],
    ),
  );
}
