import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/router/providers/flutter_local_notifications_plugin_provider.dart';
import '../../meals/data/providers/meal_ingredients_list_provider.dart';
import 'meal_dialog_state.dart';
import 'providers/device_status_provider.dart';
import 'utils/meal_advisor.dart';

part 'meal_dialog_controller.g.dart';

@riverpod
class MealDialogController extends _$MealDialogController {
  late final int mealId;

  @override
  MealDialogState build(int mealId, MealDialogStep initialStep) {
    this.mealId = mealId;
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
  ) async {
    final deviceStatusStream = await ref.read(
      deviceStatusStreamProvider.future,
    );

    return MealAdvisor().getMealAdvice(
      bg: deviceStatusStream.bg,
      iob: deviceStatusStream.iob,
      cob: deviceStatusStream.cob,
      trend: (parseTick(deviceStatusStream.tick) / 5).round(),
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

    final carbs = mealStatus?.carbsG ?? 0;
    final fatProteinExchanges = mealStatus?.proteinGrams ?? 0;
    final fatGrams = mealStatus?.fatGrams ?? 0;
    final fiberGrams = mealStatus?.fiberGrams ?? 0;
    final proteinGrams = mealStatus?.proteinGrams ?? 0;

    state = state.copyWith(
      skipMeal: false,
      step: MealDialogStep.confirm,
      carbsGrams: carbs,
      extendedCarbsGrams: fatProteinExchanges,
      advice: await _getAdvice(carbs, proteinGrams, fatGrams, fiberGrams),
    );
  }

  String? mealAdviceString() {
    switch (state.advice.decision) {
      case MealDecision.eatNowBolusLater:
        return "Jedz teraz, insulinę podaj po jedzeniu w kalkulatorze ${state.carbsGrams}g";
      case MealDecision.bolusAndEatNow:
        return "Podaj insulinę insulinę w kalkulatorze ${state.carbsGrams}g i jedz";
      case MealDecision.bolusWaitThenEat:
        return "1. Pierw podaj insulinę w kalkulatorze ${state.carbsGrams}g,\n2. ${waitTimeMessage(state.advice.wait!)}i jedz";
      case null:
        // TODO: Handle this case.
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

  Future<void> scheduleEatNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required int notificationId,
    required int minutes,
  }) async {
    final plugin = ref.read(flutterLocalNotificationsPluginProvider);
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'meal_wait_channel',
        'Meal Wait Notifications',
        channelDescription: 'Reminders that you can start eating',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await plugin.zonedSchedule(
      id: notificationId,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: 'Możesz już jeść 🍽️',
      body: 'Minęło $minutes minut od podania insuliny.',
      // payload: 'mealId=$notificationId', // opcjonalnie
    );
  }
}
