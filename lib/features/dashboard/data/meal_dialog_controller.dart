import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/l10n/language.dart';
import '../../../common/meal/manual_meal_decision.dart';
import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/meal_macro_summary.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/meal_advice_pending_notification.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import '../../meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import '../../meal_advisor/data/providers/check_meal_advisor_device_status_use_case_provider.dart';
import '../../meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../meal_advisor/data/providers/get_meal_advice_use_case_provider.dart';
import '../../meal_advisor/domain/models/meal_advice_eligibility.dart';
import '../../meal_advisor/domain/models/meal_advice_unavailable_exception.dart';
import '../../meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../meal_analysis/data/providers/build_before_meal_context_use_case_provider.dart';
import '../../meals/data/providers/meal_activation_guard_provider.dart';
import '../../meals/data/providers/meal_ingredients_list_provider.dart';
import 'meal_dialog_state.dart';
import 'providers/blood_sugar_readings_list_provider.dart';
import 'providers/device_status_ui_provider.dart';
import 'use_cases/accept_meal_decision_use_case.dart';
import 'utils/meal_advisor.dart';

part 'meal_dialog_controller.g.dart';

@riverpod
class MealDialogController extends _$MealDialogController with Logging {
  static const pendingAdviceReminderDelay = Duration(minutes: 2);

  late final int mealId;
  int _adviceRequest = 0;
  DeviceStatus? _adviceDeviceStatus;

  @override
  MealDialogState build(int mId, MealDialogStep initialStep) {
    mealId = mId;
    return MealDialogState.initial(initialStep);
  }

  String waitTimeMessage(WaitSuggestion w) {
    if (state.advice.source == 'manual') {
      return lang.mealManualWaitInstruction(w.recommendedMinutes);
    }
    return lang.mealSuggestedWaitInstruction(
      w.recommendedMinutes,
      w.minMinutes,
      w.maxMinutes,
    );
  }

  Future<void> chooseEat({ManualMealDecision? manual}) async {
    if (manual == null && state.isPreparingAdvice) return;
    final request = ++_adviceRequest;
    state = state.copyWith(
      isPreparingAdvice: true,
      preparationFailed: false,
      isAiAssisted: false,
      clearBeforeMealContext: true,
    );
    try {
      await _prepareChoice(request, manual);
    } catch (error, stack) {
      logE(
        'Meal advice preparation failed: ${error.runtimeType}',
        stackTrace: stack,
      );
      if (ref.mounted && request == _adviceRequest) {
        state = state.copyWith(
          step: MealDialogStep.confirm,
          skipMeal: false,
          advice: MealAdvice.empty(),
          extendedCarbsGrams: 0,
          preparationFailed: true,
        );
      }
    } finally {
      if (ref.mounted && request == _adviceRequest) {
        state = state.copyWith(isPreparingAdvice: false);
      }
    }
  }

  Future<void> _prepareChoice(int request, ManualMealDecision? manual) async {
    final blockingMeal = await ref.read(
      mealBlockingActivationProvider(mealId).future,
    );
    if (!ref.mounted || request != _adviceRequest) return;
    if (blockingMeal != null) {
      state = state.copyWith(
        activationBlockedByMealName: blockingMeal.name,
        step: MealDialogStep.choose,
      );
      return;
    }

    final mealStatus = await ref.read(
      mealMacronutrientsSummaryProvider(mealId).future,
    );

    if (!ref.mounted || request != _adviceRequest) return;
    final carbs = mealStatus?.netCarbsGrams ?? 0;
    if (manual != null) {
      state = state.copyWith(
        skipMeal: false,
        step: MealDialogStep.confirm,
        carbsGrams: carbs,
        extendedCarbsGrams: 0,
        advice: MealAdvice(
          manual.decision,
          manual.waitMinutes > 0
              ? WaitSuggestion(
                  manual.waitMinutes,
                  manual.waitMinutes,
                  manual.waitMinutes,
                )
              : null,
          source: 'manual',
        ),
        clearActivationBlock: true,
      );
      return;
    }
    final extendedCarbsScheduleSettings = await ref.read(
      extendedCarbsScheduleSettingsProvider.future,
    );
    if (!ref.mounted || request != _adviceRequest) return;
    final aiAssisted = ref.read(aiAssistedMealAdvisorEnabledProvider);
    state = state.copyWith(isAiAssisted: aiAssisted, carbsGrams: carbs);
    if (aiAssisted) {
      final context = await ref.read(
        buildBeforeMealContextUseCaseProvider(false),
      )(asOf: clock.now(), mealId: mealId, macros: mealStatus);
      if (!ref.mounted || request != _adviceRequest) return;
      state = state.copyWith(beforeMealContext: context);
    }
    final deviceStatus = ref.read(deviceStatusUiProvider);
    _adviceDeviceStatus = deviceStatus;
    var advice =
        ref
                    .read(checkMealAdvisorDeviceStatusUseCaseProvider)
                    .call(deviceStatus) !=
                MealAdviceEligibility.available ||
            deviceStatus == null
        ? MealAdvice.empty()
        : ref
              .read(getMealAdviceUseCaseProvider)
              .call(
                macros:
                    mealStatus ??
                    MealMacroSummary(
                      carbsGrams: 0,
                      fatGrams: 0,
                      proteinGrams: 0,
                      fiberGrams: 0,
                      totalGrams: 0,
                    ),
                deviceStatus: deviceStatus,
                settings: extendedCarbsScheduleSettings,
              );
    if (advice.decision != null) {
      final eligibility = await _checkAdviceEligibility();
      if (!ref.mounted || request != _adviceRequest) return;
      if (eligibility != MealAdviceEligibility.available ||
          ref
                  .read(checkMealAdvisorDeviceStatusUseCaseProvider)
                  .call(deviceStatus) !=
              MealAdviceEligibility.available) {
        advice = MealAdvice.empty();
      }
    }
    if (advice.decision != null) {
      await schedulePendingAdviceReminder();
      if (!ref.mounted || request != _adviceRequest) return;
    }

    state = state.copyWith(
      skipMeal: false,
      step: MealDialogStep.confirm,
      carbsGrams: carbs,
      extendedCarbsGrams: advice.extendedCarbs.grams.toDouble(),
      advice: advice,
      clearActivationBlock: true,
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
        return lang.mealEatThenBolusInstruction(carbsText, extendedCarbsText);
      case MealDecision.bolusAndEatNow:
        return lang.mealBolusAndEatInstruction(carbsText, extendedCarbsText);
      case MealDecision.bolusWaitThenEat:
        return lang.mealBolusWaitEatInstruction(
          carbsText,
          waitTimeMessage(state.advice.wait!),
          extendedCarbsText,
        );
      case null:
        throw UnimplementedError();
      case MealDecision.bolus:
        throw UnimplementedError();
    }
  }

  /// Returns false if the choice changed while its inputs were being checked.
  Future<bool> confirmAdvice() async {
    if (state.isPreparingAdvice) return false;
    final request = _adviceRequest;
    final advice = state.advice;
    final adviceDeviceStatus = _adviceDeviceStatus;
    if (advice.source != 'manual') {
      final eligibility = await _checkAdviceEligibility();
      if (!ref.mounted ||
          request != _adviceRequest ||
          !identical(state.advice, advice)) {
        return false;
      }
      final statusEligibility = ref
          .read(checkMealAdvisorDeviceStatusUseCaseProvider)
          .call(ref.read(deviceStatusUiProvider));
      if (eligibility != MealAdviceEligibility.available ||
          statusEligibility != MealAdviceEligibility.available ||
          ref
                  .read(checkMealAdvisorDeviceStatusUseCaseProvider)
                  .call(adviceDeviceStatus) !=
              MealAdviceEligibility.available) {
        state = state.copyWith(
          advice: MealAdvice.empty(),
          extendedCarbsGrams: 0,
        );
        await cancelAllMealNotifications();
        throw const MealAdviceUnavailableException();
      }
    }
    await AcceptMealDecisionUseCase(ref).call(mealId, advice);
    return true;
  }

  /// End this attempt immediately; late context/history results cannot change the choice.
  void cancelAdvicePreparation() {
    if (!state.isPreparingAdvice) return;
    _adviceRequest++;
    state = state.copyWith(
      isPreparingAdvice: false,
      step: MealDialogStep.confirm,
      skipMeal: false,
      advice: MealAdvice.empty(),
      extendedCarbsGrams: 0,
      clearBeforeMealContext: true,
      preparationFailed: false,
    );
  }

  Future<MealAdviceEligibility> _checkAdviceEligibility() async {
    final check = ref.read(checkMealAdviceEligibilityUseCaseProvider);
    final readings = ref.read(bloodSugarReadingsListProvider).asData?.value;
    // A complete, fresh CGM sequence already displayed on this phone needs no cloud round trip.
    if (readings != null &&
        check.evaluate(readings, clock.now()) ==
            MealAdviceEligibility.available) {
      return MealAdviceEligibility.available;
    }
    return check();
  }

  void chooseSkip() {
    _adviceRequest++;
    state = state.copyWith(
      skipMeal: true,
      preparationFailed: false,
      isPreparingAdvice: false,
      clearBeforeMealContext: true,
      step: MealDialogStep.confirm,
      clearActivationBlock: true,
    );
  }

  void back() {
    _adviceRequest++;
    if (state.step != MealDialogStep.confirm && !state.isPreparingAdvice) {
      return;
    }
    state = state.copyWith(
      step: MealDialogStep.choose,
      isPreparingAdvice: false,
      preparationFailed: false,
      clearBeforeMealContext: true,
    );
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
