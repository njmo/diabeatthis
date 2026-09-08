import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/analysis_timeline_row.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';

class MealTimelineEventTile extends StatelessWidget {
  final int mealId;
  final MealTimelineEventData event;
  final DateTime referenceTime;
  final bool selected;
  final VoidCallback onSelected;

  const MealTimelineEventTile({
    super.key,
    required this.mealId,
    required this.event,
    required this.referenceTime,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final value = timelineEventValueLabel(event);
    final hasLink =
        event.activityLogId != null ||
        (event.mealId != null && event.mealId != mealId);
    return AnalysisTimelineRow(
      selected: selected,
      icon: mealTimelineEventIcon(event.type),
      time: mealTime(event.timestamp),
      title: timelineEventLabel(event),
      detail: [
        formatDurationOffset(event.timestamp.difference(referenceTime)),
        if (value != null) value,
      ].join(' · '),
      onTap: onSelected,
      trailing: hasLink
          ? IconButton(
              tooltip: context.lang.mealReviewOpenRelated,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => event.activityLogId != null
                  ? context.router.push(
                      ActivityLogRoute(activityLogId: event.activityLogId!),
                    )
                  : context.router.push(MealRoute(mealId: event.mealId!)),
            )
          : null,
    );
  }
}
