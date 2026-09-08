import 'package:flutter/material.dart';

import '../../../../../common/history/history_event_presentation.dart';
import '../../../data/models/meal_analysis_data.dart';

IconData mealTimelineEventIcon(MealTimelineEventType type) =>
    historyEventIcon(type);
Color mealTimelineEventColor(MealTimelineEventType type) =>
    historyEventColor(type);

IconData mealStatusIcon(String status) {
  return switch (status) {
    'planned' => Icons.schedule,
    'waiting-for-bolus' => Icons.medication,
    'bolused-waiting' => Icons.hourglass_top,
    'bolused-eating' => Icons.restaurant,
    'eating-extra' => Icons.add_circle,
    'eaten' ||
    'eaten-extra' ||
    'eaten-bolused' ||
    'summarized' => Icons.check_circle,
    'skipped' => Icons.cancel,
    _ => Icons.flag,
  };
}
