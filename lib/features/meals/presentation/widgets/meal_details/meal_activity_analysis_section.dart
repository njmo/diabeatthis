import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../app/router/app_router.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../controllers/meal_details_controller.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';

class MealActivityAnalysisSection extends ConsumerWidget {
  final int mealId;
  final MealAnalysisData analysis;
  final DateTime? selectedTimestamp;

  const MealActivityAnalysisSection({
    super.key,
    required this.mealId,
    required this.analysis,
    required this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MealSectionTile(
      title: 'Aktywności i zdarzenia',
      children: [
        MealEventTimeline(
          events: analysis.timelineEvents,
          selectedTimestamp: selectedTimestamp,
          onSelected: (timestamp) {
            ref
                .read(mealDetailsControllerProvider(mealId).notifier)
                .selectTimestamp(timestamp);
          },
        ),
        const SizedBox(height: 8),
        for (final event in analysis.timelineEvents)
          ListTile(
            dense: true,
            leading: Icon(
              mealTimelineEventIcon(event.type),
              color: mealTimelineEventColor(event.type),
            ),
            title: Text(
              '${mealTime(event.timestamp)} • ${timelineEventLabel(event)}',
            ),
            subtitle: event.value == null ? null : Text(event.value!),
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
          ),
      ],
    );
  }
}

class MealEventTimeline extends StatelessWidget {
  final List<MealTimelineEventData> events;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime> onSelected;

  const MealEventTimeline({
    super.key,
    required this.events,
    required this.selectedTimestamp,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  mealTimelineEventIcon(event.type),
                  size: 16,
                  color: mealTimelineEventColor(event.type),
                ),
                label: Text(
                  '${mealTime(event.timestamp)} ${timelineEventLabel(event)}',
                ),
                selected:
                    selectedTimestamp != null &&
                    selectedTimestamp!
                            .difference(event.timestamp)
                            .inMinutes
                            .abs() <=
                        2,
                onSelected: (_) => onSelected(event.timestamp),
              ),
            ),
        ],
      ),
    );
  }
}
