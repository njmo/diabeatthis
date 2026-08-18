import '../../../../common/l10n/language.dart';
import 'extended_carbs_schedule_settings.dart';

String formatExtendedCarbsSchedule(
  int grams, {
  ExtendedCarbsScheduleSettings settings =
      const ExtendedCarbsScheduleSettings.defaults(),
}) {
  if (grams <= 0) return lang.extendedCarbsScheduleNone;

  return switch (settings.deliveryMode) {
    ExtendedCarbsDeliveryMode.extendedCarbs =>
      lang.extendedCarbsScheduleExtended(
        grams,
        formatExtendedCarbsScheduleMinutes(settings.delayMinutes),
        formatExtendedCarbsScheduleMinutes(settings.durationMinutes),
      ),
    ExtendedCarbsDeliveryMode.extraBolus =>
      lang.extendedCarbsScheduleExtraBolus(
        grams,
        formatExtendedCarbsScheduleMinutes(settings.delayMinutes),
      ),
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
      lang.extendedCarbsInstructionExtended(
        formatExtendedCarbsSchedule(grams, settings: settings),
      ),
    ExtendedCarbsDeliveryMode.extraBolus =>
      lang.extendedCarbsInstructionExtraBolus(
        formatExtendedCarbsSchedule(grams, settings: settings),
      ),
  };
}

String formatExtendedCarbsScheduleMinutes(int minutes) {
  if (minutes == 60) return lang.durationOneHourShort;
  if (minutes > 0 && minutes % 60 == 0) {
    return lang.durationHoursShort(minutes ~/ 60);
  }
  return lang.durationMinutesShort(minutes);
}
