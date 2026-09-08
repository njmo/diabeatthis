import 'package:flutter/material.dart';

import '../l10n/language.dart';
import 'history_event_type.dart';

IconData historyEventIcon(HistoryEventType type) {
  return switch (type) {
    HistoryEventType.bgCheck => Icons.bloodtype_outlined,
    HistoryEventType.stress => Icons.psychology_outlined,
    HistoryEventType.manualCorrection => Icons.person_outline,
    HistoryEventType.carbs => Icons.bakery_dining,
    HistoryEventType.correction => Icons.medical_services,
    HistoryEventType.activity => Icons.directions_run,
    HistoryEventType.mealStatus => Icons.flag,
    HistoryEventType.localMeal => Icons.restaurant,
    HistoryEventType.lowTreatment => Icons.bloodtype_outlined,
    HistoryEventType.nightscoutMeal => Icons.cloud_done,
    HistoryEventType.deviceStatus => Icons.sensors,
    HistoryEventType.tempTarget => Icons.timer,
  };
}

Color historyEventColor(HistoryEventType type) {
  return switch (type) {
    HistoryEventType.bgCheck => Colors.red,
    HistoryEventType.stress => Colors.orange,
    HistoryEventType.manualCorrection => Colors.blue,
    HistoryEventType.carbs => Colors.green,
    HistoryEventType.correction => Colors.deepPurple,
    HistoryEventType.activity => Colors.teal,
    HistoryEventType.mealStatus => Colors.orange,
    HistoryEventType.localMeal => Colors.brown,
    HistoryEventType.lowTreatment => Colors.redAccent,
    HistoryEventType.nightscoutMeal => Colors.indigo,
    HistoryEventType.deviceStatus => Colors.grey,
    HistoryEventType.tempTarget => Colors.blue,
  };
}

String historyEventLabel(AppLocalizations messages, HistoryEventType type) =>
    switch (type) {
      HistoryEventType.bgCheck => messages.historyBgCheck,
      HistoryEventType.stress => messages.manualEventStress,
      HistoryEventType.manualCorrection => messages.mealReviewManualCorrection,
      HistoryEventType.carbs => messages.mealCarbsLabel,
      HistoryEventType.correction => messages.mealTimelineCorrection,
      HistoryEventType.activity => messages.activityLegendActivity,
      HistoryEventType.mealStatus => messages.activityTreatmentEvent,
      HistoryEventType.localMeal => messages.mealTimelineLocalMeal,
      HistoryEventType.lowTreatment => messages.lowTreatmentTitle,
      HistoryEventType.nightscoutMeal => messages.mealTimelineNightscoutMeal,
      HistoryEventType.deviceStatus => messages.mealTimelineDeviceStatus,
      HistoryEventType.tempTarget => messages.historyTemporaryTarget,
    };
