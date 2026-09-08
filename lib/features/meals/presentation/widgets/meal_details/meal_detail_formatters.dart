import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_analysis_data.dart';

String mealDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

String mealDateTimeOrDash(DateTime? date) {
  return date == null ? '-' : mealDateTime(date);
}

String mealTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String fallbackText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return '-';
  return text;
}

String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

String formatMgdl(int? value) => value == null ? '-' : '$value mg/dL';

String formatGrams(double? value) {
  return value == null ? '-' : '${formatNumber(value)}g';
}

String formatSignedGrams(double? value) {
  if (value == null) return '-';
  final prefix = value > 0 ? '+' : '';
  return '$prefix${formatNumber(value)}g';
}

String formatUnits(double? value) {
  return value == null ? '-' : '${value.toStringAsFixed(2)}U';
}

String formatPercent(double? value) {
  return value == null ? '-' : '${value.round()}%';
}

String formatConfidence(double? value) {
  return value == null ? '-' : '${(value * 100).round()}%';
}

String formatDurationOffset(Duration? duration) {
  if (duration == null) return '-';
  final sign = duration.isNegative ? '-' : '+';
  return '$sign${duration.inMinutes.abs()} min';
}

String formatDelayAfterMeal(Duration? duration) {
  if (duration == null) return '-';
  final minutes = duration.inMinutes.abs();
  if (duration.isNegative) {
    return 'przed $minutes min';
  }
  return 'po $minutes min';
}

String formatShare(double value, double total) {
  if (total <= 0) return '-';
  return '${(value / total * 100).round()}%';
}

String formatSnapshotValue(double? value, String unit) {
  if (value == null) return '-';
  return '${formatNumber(value)}$unit';
}

String formatSnapshotDiff(double? value, String unit) {
  if (value == null) return '-';
  final prefix = value > 0 ? '+' : '';
  return '$prefix${formatNumber(value)}$unit';
}

String formatNutritionValue(double value, String unit) {
  if (unit.isEmpty) {
    return formatConfidence(value);
  }
  return '${formatNumber(value)}$unit';
}

String mealStatusLabel(String status) {
  return switch (status) {
    'planned' => lang.mealStatusPlanned,
    'waiting-for-bolus' => lang.mealStatusWaitingForBolus,
    'bolused-waiting' => lang.mealStatusBolusedWaiting,
    'bolused-eating' => lang.mealStatusBolusedEating,
    'waited-eating' => lang.mealStatusWaitedEating,
    'eating' => lang.mealStatusEating,
    'eating-extra' => lang.mealStatusEatingExtra,
    'eating-then-bolus' => lang.mealStatusEatingThenBolus,
    'eaten' => lang.mealStatusEaten,
    'eaten-extra' => lang.mealStatusEatenExtra,
    'eaten-bolused' => lang.mealStatusEatenBolused,
    'summarized' => lang.mealStatusSummarized,
    'skipped' => lang.mealStatusSkipped,
    _ => status,
  };
}

String mealEntryTypeLabel(String entryType) {
  return switch (entryType) {
    'planned' => lang.mealEntryPlanned,
    'extra' => lang.mealEntryExtra,
    _ => entryType,
  };
}

String timelineEventLabel(MealTimelineEventData event) {
  return switch (event.type) {
    MealTimelineEventType.manualCorrection => lang.mealReviewManualCorrection,
    MealTimelineEventType.carbs => lang.mealCarbsLabel,
    MealTimelineEventType.correction => lang.mealTimelineCorrection,
    MealTimelineEventType.activity => event.label,
    MealTimelineEventType.mealStatus => mealStatusLabel(event.label),
    MealTimelineEventType.localMeal =>
      event.label == 'Meal eaten'
          ? lang.mealTimelineLocalMealEaten
          : lang.mealTimelineLocalMeal,
    MealTimelineEventType.lowTreatment => lang.lowTreatmentTitle,
    MealTimelineEventType.nightscoutMeal => lang.mealTimelineNightscoutMeal,
    MealTimelineEventType.deviceStatus => lang.mealTimelineDeviceStatus,
    MealTimelineEventType.tempTarget => 'Temp target',
  };
}

String? timelineEventValueLabel(MealTimelineEventData event) {
  final value = event.value;
  if (value == null) return null;

  return switch (event.type) {
    MealTimelineEventType.mealStatus =>
      value == 'current status' ? lang.mealTimelineCurrentStatus : value,
    MealTimelineEventType.localMeal =>
      event.label == 'Meal eaten' ? value : mealStatusLabel(value),
    _ => value,
  };
}
