import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/eat_now_event_notification.dart';
import '../../../core/notifications/domain/events/meal_advice_pending_notification.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../meals/data/providers/meal_ingredients_list_provider.dart';
import 'meal_dialog_state.dart';
import 'providers/device_status_ui_provider.dart';
import 'utils/meal_advisor.dart';

part 'meal_dialog_controller.g.dart';

@riverpod
class MealDialogController extends _$MealDialogController with Logging {
  static const pendingAdviceReminderDelay = Duration(minutes: 2);

  late final int mealId;

  @override
  MealDialogState build(int mId, MealDialogStep initialStep) {
    mealId = mId;
    return MealDialogState.initial(initialStep);
  }

  String waitTimeMessage(WaitSuggestion w) {
    return "Odczekaj około ${w.recommendedMinutes} min "
        "(zakres ${w.minMinutes}–${w.maxMinutes} min) przed rozpoczęciem posiłku.";
  }

  int parseTick(String? tickRaw) {
    if (tickRaw == null) return 0;
    final cleaned = tickRaw.trim().replaceAll(',', '.');
    return int.tryParse(cleaned) ??
        int.tryParse(cleaned.replaceAll('+', '')) ??
        0;
  }

  Future<MealAdvice?> _getAdvice(
    double carbs,
    double fatGrams,
    double proteinGrams,
    double fiberGrams,
    ExtendedCarbsScheduleSettings extendedCarbsScheduleSettings,
  ) async {
    final deviceStatusValue = ref.read(deviceStatusUiProvider);
    if (deviceStatusValue == null) return null;

    return MealAdvisor(
      config: MealAdvisorConfig(
        extendedCarbsScheduleSettings: extendedCarbsScheduleSettings,
      ),
    ).getMealAdvice(
      bg: deviceStatusValue.bg,
      iob: deviceStatusValue.iob,
      cob: deviceStatusValue.cob,
      trend: (parseTick(deviceStatusValue.tick) / 5).round(),
      mealCarbs: carbs,
      fatGrams: fatGrams,
      proteinGrams: proteinGrams,
      fiberGrams: fiberGrams,
    );
  }

  Future<void> chooseEat() async {
    final mealStatus = await ref.read(
      mealMacronutrientsSummaryProvider(mealId).future,
    );

    final carbs = mealStatus?.netCarbsGrams ?? 0;
    final fatGrams = mealStatus?.fatGrams ?? 0;
    final fiberGrams = mealStatus?.fiberGrams ?? 0;
    final proteinGrams = mealStatus?.proteinGrams ?? 0;
    final extendedCarbsScheduleSettings = await ref.read(
      extendedCarbsScheduleSettingsProvider.future,
    );
    final advice =
        await _getAdvice(
          carbs,
          fatGrams,
          proteinGrams,
          fiberGrams,
          extendedCarbsScheduleSettings,
        ) ??
        MealAdvice.empty();
    if (advice.decision != null) {
      await schedulePendingAdviceReminder();
    }

    state = state.copyWith(
      skipMeal: false,
      step: MealDialogStep.confirm,
      carbsGrams: carbs,
      extendedCarbsGrams: advice.extendedCarbs.grams.toDouble(),
      advice: advice,
    );
  }

  String? mealAdviceString() {
    final carbsText = state.carbsGrams.ceil().toString();
    final extendedCarbs = state.extendedCarbsGrams.ceil();
    final extendedCarbsText = extendedCarbs > 0
        ? '\n${formatExtendedCarbsInstruction(extendedCarbs, settings: state.advice.extendedCarbs.scheduleSettings)}'
        : '';

    switch (state.advice.decision) {
      case MealDecision.eatNowBolusLater:
        return "Jedz teraz, insulinę podaj po jedzeniu w kalkulatorze ${carbsText}g$extendedCarbsText";
      case MealDecision.bolusAndEatNow:
        return "Podaj insulinę w kalkulatorze ${carbsText}g i jedz$extendedCarbsText";
      case MealDecision.bolusWaitThenEat:
        return "1. Najpierw podaj insulinę w kalkulatorze ${carbsText}g,\n2. ${waitTimeMessage(state.advice.wait!)} i jedz$extendedCarbsText";
      case null:
        throw UnimplementedError();
      case MealDecision.bolus:
        throw UnimplementedError();
    }
  }

  void chooseSkip() {
    state = state.copyWith(skipMeal: true, step: MealDialogStep.confirm);
  }

  void back() {
    if (state.step == MealDialogStep.confirm) {
      state = state.copyWith(
        step: state.skipMeal ? MealDialogStep.choose : MealDialogStep.choose,
      );
    }
  }

  Future<void> scheduleEatNotification({required int minutes}) async {
    final notificationsPluginController = ref.read(
      notificationsControllerUiProvider,
    );
    final when = Duration(minutes: minutes);

    logI("SCHEDULING NOTIFICATION IN ${when.toString()}");

    try {
      final event = EatNowNotificationEvent(mealId: mealId, minutes: minutes);

      await notificationsPluginController.schedule(event, when);

      final pending = await notificationsPluginController.pending;
      logI('Pending IDs: $pending');
    } catch (e) {
      logE('Error scheduling notification: $e');
    }
  }

  Future<void> schedulePendingAdviceReminder() async {
    final notificationsPluginController = ref.read(
      notificationsControllerUiProvider,
    );
    final event = MealAdvicePendingNotificationEvent(mealId: mealId);

    try {
      await notificationsPluginController.schedule(
        event,
        pendingAdviceReminderDelay,
      );
    } catch (e) {
      logE('Error scheduling pending meal advice reminder: $e');
    }
  }

  Future<void> cancelAllMealNotifications() async {
    final notificationsPluginController = ref.read(
      notificationsControllerUiProvider,
    );

    try {
      await notificationsPluginController.cancelAll();
    } catch (e) {
      logE('Error cancelling meal notifications: $e');
    }
  }
}
