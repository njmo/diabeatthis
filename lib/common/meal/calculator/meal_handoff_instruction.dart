import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
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
        if (hasExtendedCarbs)
          HandoffStep(
            label: event.extendedCarbsAreAdditional
                ? strings.aapsPipAdditionalExtendedCarbs
                : strings.aapsPipExtendedCarbs,
            value: '${event.extendedCarbs} g',
            actionId: extendedCarbsAction,
          ),
        if (hasExtendedCarbs && delay != null && duration != null)
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
