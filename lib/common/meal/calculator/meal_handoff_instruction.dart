import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../features/meal_advisor/domain/models/meal_activity_dose_suggestion.dart';
import '../../../features/meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../handoff/handoff_instruction.dart';
import '../../handoff/handoff_step.dart';
import '../../l10n/language.dart';

class MealHandoffInstruction {
  static const bolusAction = 'meal.bolus';
  static const extendedCarbsAction = 'meal.extendedCarbs';

  static HandoffInstruction build(
    AapsBolusSuggestionNotificationEvent event,
    AppLocalizations strings,
  ) {
    final suggestion = event.activityDoseSuggestion;
    final delay = event.extendedCarbsDelayMinutes;
    final duration = event.extendedCarbsDurationMinutes;
    final schedule =
        event.extendedCarbs > 0 && delay != null && duration != null
        ? strings.aapsPipSchedule(
            formatExtendedCarbsScheduleMinutes(delay),
            formatExtendedCarbsScheduleMinutes(duration),
          )
        : strings.aapsPipNoSchedule;
    final hasExtendedCarbs = event.extendedCarbs > 0;
    return HandoffInstruction(
      title: event.mealName?.trim().isNotEmpty == true
          ? event.mealName!.trim()
          : strings.aapsSuggestionTitle,
      closeLabel: strings.aapsSuggestionClose,
      steps: [
        HandoffStep(
          label: strings.aapsPipCarbs,
          value: '${event.carbs} g',
          actionId: bolusAction,
        ),
        if (event.hasActivityDoseSuggestion && suggestion != null)
          HandoffStep(
            label: strings.mealActivityDoseProposal(suggestion.dosePercent),
            value:
                '${switch (suggestion.phase) {
                  MealActivityPhase.upcoming => strings.mealActivityUpcoming,
                  MealActivityPhase.ongoing => strings.mealActivityOngoing,
                  MealActivityPhase.completed => strings.mealActivityCompleted,
                }} · ${suggestion.activityName}',
            actionId: bolusAction,
            showCheckbox: false,
            prominent: true,
          ),
        if (hasExtendedCarbs)
          HandoffStep(
            label: event.extendedCarbsAreAdditional
                ? strings.aapsPipAdditionalExtendedCarbs
                : strings.aapsPipExtendedCarbs,
            value:
                event.hasActivityDoseSuggestion &&
                    delay != null &&
                    duration != null
                ? '${event.extendedCarbs} g · $schedule'
                : '${event.extendedCarbs} g',
            actionId: extendedCarbsAction,
          ),
        if (hasExtendedCarbs &&
            delay != null &&
            duration != null &&
            !event.hasActivityDoseSuggestion)
          HandoffStep(
            label: strings.aapsPipTime,
            value: schedule,
            actionId: extendedCarbsAction,
            showCheckbox: false,
          ),
      ],
    );
  }
}
