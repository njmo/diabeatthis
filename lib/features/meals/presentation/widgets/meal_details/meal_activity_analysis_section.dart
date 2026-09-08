import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_timeline_event_tile.dart';

class MealActivityAnalysisSection extends StatelessWidget {
  final int mealId;
  final MealAnalysisData analysis;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime> onTimestampSelected;

  const MealActivityAnalysisSection({
    super.key,
    required this.mealId,
    required this.analysis,
    required this.onTimestampSelected,
    this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final events = [...analysis.timelineEvents]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final primary = events.where((event) => !isSupportingEvent(event)).toList();
    final supporting = events.where(isSupportingEvent).toList();
    Widget tile(MealTimelineEventData event) => MealTimelineEventTile(
      mealId: mealId,
      event: event,
      referenceTime: analysis.mealTime,
      selected: event.timestamp == selectedTimestamp,
      onSelected: () => onTimestampSelected(event.timestamp),
    );
    return DetailSectionCard(
      title: context.lang.mealReviewEvents,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            events.isEmpty
                ? context.lang.mealReviewNoEvents
                : context.lang.mealReviewEventHint,
          ),
        ),
        for (final event in primary) tile(event),
        if (supporting.isNotEmpty)
          ExpansionTile(
            title: Text(context.lang.mealReviewAllEvents),
            children: [for (final event in supporting) tile(event)],
          ),
      ],
    );
  }

  bool isSupportingEvent(MealTimelineEventData event) =>
      event.type == MealTimelineEventType.deviceStatus ||
      event.type == MealTimelineEventType.mealStatus;
}
