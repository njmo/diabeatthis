import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_save_event.dart';
import 'meal_event_timeline_row.dart';

class MealSaveTimeline extends StatelessWidget {
  const MealSaveTimeline({
    super.key,
    required this.events,
    required this.formatTime,
  });
  final List<MealSaveEvent> events;
  final String Function(DateTime time) formatTime;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          MealEventTimelineRow(
            title: switch (events[i].kind) {
              MealSaveEventKind.created => lang.mealSaveCreatedEvent,
              MealSaveEventKind.updated => lang.mealSaveUpdatedEvent,
              MealSaveEventKind.advisorCreated => lang.mealAdvisorCreatedEvent,
              MealSaveEventKind.advisorUpdated => lang.mealAdvisorUpdatedEvent,
              MealSaveEventKind.summarized => lang.mealSummarizedAtLabel,
            },
            icon: switch (events[i].kind) {
              MealSaveEventKind.created => Icons.add_circle_outline,
              MealSaveEventKind.updated => Icons.edit_outlined,
              MealSaveEventKind.advisorCreated => Icons.psychology_outlined,
              MealSaveEventKind.advisorUpdated => Icons.update,
              MealSaveEventKind.summarized => Icons.task_alt,
            },
            detail: formatTime(events[i].at),
            last: i == events.length - 1,
          ),
      ],
    );
  }
}
