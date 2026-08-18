import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../controllers/meal_details_controller.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';

class MealActivityAnalysisSection extends ConsumerWidget {
  final int mealId;
  final MealAnalysisData analysis;

  const MealActivityAnalysisSection({
    super.key,
    required this.mealId,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MealSectionTile(
      title: context.lang.mealActivityEventsTitle,
      children: [
        for (final event in analysis.timelineEvents) ...[
          MealTimelineEventTile(mealId: mealId, event: event),
        ],
      ],
    );
  }
}

class MealTimelineEventTile extends ConsumerWidget {
  final int mealId;
  final MealTimelineEventData event;

  const MealTimelineEventTile({
    super.key,
    required this.mealId,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueLabel = timelineEventValueLabel(event);

    return ListTile(
      dense: true,
      leading: Icon(
        mealTimelineEventIcon(event.type),
        color: mealTimelineEventColor(event.type),
      ),
      title: Text(
        '${mealTime(event.timestamp)} • ${timelineEventLabel(event)}',
      ),
      subtitle: valueLabel == null ? null : Text(valueLabel),
      trailing: event.activityLogId != null || event.mealId != null
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: event.activityLogId != null
          ? () => context.router.push(
              ActivityLogRoute(activityLogId: event.activityLogId!),
            )
          : event.mealId != null
          ? () => context.router.push(MealRoute(mealId: event.mealId!))
          : null,
      onLongPress: () {
        ref
            .read(mealDetailsControllerProvider(mealId).notifier)
            .selectTimestamp(event.timestamp);
      },
    );
  }
}
