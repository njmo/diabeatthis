import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../app/router/providers/flutter_local_notifications_plugin_provider.dart';
import '../../meals/data/providers/meal_ingredients_list_provider.dart';
import 'meal_dialog_state.dart';
import 'providers/device_status_provider.dart';
import 'utils/meal_advisor.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

part 'meal_dialog_controller.g.dart';

@riverpod
class MealDialogController extends _$MealDialogController {
  late final int meal_id;

  @override
  MealDialogState build(int mealId) {
    meal_id = mealId;
    final s = MealDialogState.initial();
    return s.copyWith(waitHint: "Ładowanie…");
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
  Future<String?> _computeWaitHint(double  carbs, double fatProteinExchanges) async {
    final deviceStatusStream = await ref.read(
      deviceStatusStreamProvider.future,
    );

    final advice = MealAdvisor().getMealAdvice(bg: deviceStatusStream.bg, iob: deviceStatusStream.iob, cob: deviceStatusStream.cob, trend: parseTick(deviceStatusStream.tick), mealCarbs: carbs, fatProteinExchanges: fatProteinExchanges);
    return mealAdviceLabel(advice);
  }

  Future<void> chooseEat() async {
    final mealStatus = await ref.read(
      mealMacronutrientsSummaryProvider(meal_id).future,
    );

    state = state.copyWith(
      skipMeal: false,
      step: MealDialogStep.details,
      carbsGrams: mealStatus?.carbsG,
      extendedCarbsGrams: (mealStatus!.fatKcal + mealStatus.proteinKcal) / 10.0,
      waitHint: await _computeWaitHint(state.carbsGrams, state.extendedCarbsGrams),
    );
  }

  String? mealAdviceLabel(MealAdvice advice) {
    switch (advice.decision) {
      case MealDecision.eatNowBolusLater:
        return "Jedz teraz, insulinę podaj później";
      case MealDecision.bolusAndEatNow:
        return "Podaj insulinę i jedz";
      case MealDecision.bolusWaitThenEat:
        return "Podaj insulinę, odczekaj ${waitTimeMessage(advice.wait!)}i jedz";
      case MealDecision.eatSnackFirst:
        return "Najpierw mała przekąska";
    }
  }

  void chooseSkip() {
    state = state.copyWith(skipMeal: true, step: MealDialogStep.confirm);
  }

  void back() {
    if (state.step == MealDialogStep.details) {
      state = state.copyWith(step: MealDialogStep.choose);
    } else if (state.step == MealDialogStep.confirm) {
      state = state.copyWith(
        step: state.skipMeal ? MealDialogStep.choose : MealDialogStep.details,
      );
    }
  }

  void next() {
    if (state.step == MealDialogStep.details) {
      state = state.copyWith(step: MealDialogStep.confirm);
    }
  }

  Future<void> save() async {}
}
