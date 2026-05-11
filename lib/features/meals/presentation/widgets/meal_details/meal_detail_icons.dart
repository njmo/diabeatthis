import 'package:flutter/material.dart';

import '../../../data/models/meal_analysis_data.dart';

IconData mealTimelineEventIcon(MealTimelineEventType type) {
  return switch (type) {
    MealTimelineEventType.insulin => Icons.vaccines,
    MealTimelineEventType.carbs => Icons.bakery_dining,
    MealTimelineEventType.correction => Icons.medical_services,
    MealTimelineEventType.activity => Icons.directions_run,
    MealTimelineEventType.mealStatus => Icons.flag,
    MealTimelineEventType.localMeal => Icons.restaurant,
    MealTimelineEventType.nightscoutMeal => Icons.cloud_done,
    MealTimelineEventType.deviceStatus => Icons.sensors,
    MealTimelineEventType.tempTarget => Icons.timer,
  };
}

Color mealTimelineEventColor(MealTimelineEventType type) {
  return switch (type) {
    MealTimelineEventType.insulin => Colors.blue,
    MealTimelineEventType.carbs => Colors.green,
    MealTimelineEventType.correction => Colors.deepPurple,
    MealTimelineEventType.activity => Colors.teal,
    MealTimelineEventType.mealStatus => Colors.orange,
    MealTimelineEventType.localMeal => Colors.brown,
    MealTimelineEventType.nightscoutMeal => Colors.indigo,
    MealTimelineEventType.deviceStatus => Colors.grey,
    MealTimelineEventType.tempTarget => Colors.blue,
  };
}

IconData mealStatusIcon(String status) {
  return switch (status) {
    'planned' => Icons.schedule,
    'bolused-waiting' => Icons.hourglass_top,
    'bolused-eating' => Icons.restaurant,
    'eaten' || 'eaten-bolused' || 'summarized' => Icons.check_circle,
    'skipped' => Icons.cancel,
    _ => Icons.flag,
  };
}
