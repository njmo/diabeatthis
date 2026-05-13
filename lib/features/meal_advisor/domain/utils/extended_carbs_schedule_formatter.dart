import 'extended_carbs_schedule_settings.dart';

String formatExtendedCarbsSchedule(
  int grams, {
  ExtendedCarbsScheduleSettings settings =
      const ExtendedCarbsScheduleSettings.defaults(),
}) {
  if (grams <= 0) return 'Brak';

  return switch (settings.deliveryMode) {
    ExtendedCarbsDeliveryMode.extendedCarbs =>
      '$grams g • start po ${formatExtendedCarbsScheduleMinutes(settings.delayMinutes)}'
          ' • przez ${formatExtendedCarbsScheduleMinutes(settings.durationMinutes)}',
    ExtendedCarbsDeliveryMode.extraBolus =>
      '$grams g • dodatkowy bolus po ${formatExtendedCarbsScheduleMinutes(settings.delayMinutes)}',
  };
}

String formatExtendedCarbsInstruction(
  int grams, {
  ExtendedCarbsScheduleSettings settings =
      const ExtendedCarbsScheduleSettings.defaults(),
}) {
  if (grams <= 0) return '';

  return switch (settings.deliveryMode) {
    ExtendedCarbsDeliveryMode.extendedCarbs =>
      'Przed jedzeniem zaplanuj extended carbs: '
          '${formatExtendedCarbsSchedule(grams, settings: settings)}.',
    ExtendedCarbsDeliveryMode.extraBolus =>
      'Zaplanuj przypomnienie o dodatkowym bolusie WBT: '
          '${formatExtendedCarbsSchedule(grams, settings: settings)}.',
  };
}

String formatExtendedCarbsScheduleMinutes(int minutes) {
  if (minutes == 60) return '1 godz.';
  if (minutes > 0 && minutes % 60 == 0) return '${minutes ~/ 60} godz.';
  return '$minutes min';
}
