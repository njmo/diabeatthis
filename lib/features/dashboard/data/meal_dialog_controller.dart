import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/meal/manual_meal_decision.dart';
import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/meal_macro_summary.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/meal_advice_pending_notification.dart';
import '../../../core/notifications/domain/models/hash_notification_id_factory.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import '../../meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import '../../meal_advisor/data/providers/check_meal_advisor_device_status_use_case_provider.dart';
import '../../meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../meal_advisor/data/providers/get_meal_advice_use_case_provider.dart';
import '../../meal_advisor/data/providers/meal_advisor_context_provider.dart';
import '../../meal_advisor/data/providers/resolve_meal_advisor_device_status_use_case_provider.dart';
import '../../meal_advisor/domain/models/meal_advice_eligibility.dart';
import '../../meal_advisor/domain/models/meal_advice_unavailable_exception.dart';
import '../../meal_advisor/domain/serialization/meal_advisor_dml.dart';
import '../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../../meal_analysis/data/providers/build_before_meal_context_use_case_provider.dart';
import '../../meals/data/providers/meal_activation_guard_provider.dart';
import '../../meals/data/providers/meal_ingredients_list_provider.dart';
import 'meal_dialog_state.dart';
import 'providers/blood_sugar_readings_list_provider.dart';
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

  Future<void> chooseEat({ManualMealDecision? manual}) async {
    if (manual == null && state.isPreparingAdvice) return;
    final request = ++_adviceRequest;
    state = state.copyWith(
      isPreparingAdvice: true,
      preparationFailed: false,
      isAiAssisted: false,
      clearBeforeMealContext: true,
      clearUnavailableReason: true,
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

    // Editing the start order keeps the quantities that were already reviewed.
    final preservePreparedAdvice =
        manual != null && state.advice.decision != null;
    final mealStatus = preservePreparedAdvice
        ? null
        : await ref.read(mealMacronutrientsSummaryProvider(mealId).future);

    if (!ref.mounted || request != _adviceRequest) return;
    if (!preservePreparedAdvice && mealStatus == null) {
      throw StateError('Meal nutrition is unavailable');
    }
    final carbs = preservePreparedAdvice
        ? state.carbsGrams
        : mealStatus?.netCarbsGrams ?? 0;
    if (manual != null) {
      var extendedCarbs = state.advice.extendedCarbs;
      if (!preservePreparedAdvice) {
        final settings = await ref.read(
          extendedCarbsScheduleSettingsProvider.future,
        );
        if (!ref.mounted || request != _adviceRequest) return;
        // Nutrition does not depend on CGM availability or the chosen start order.
        extendedCarbs = const WbtExtendedCarbsCalculator()
            .calculateFromMacros(
              fatGrams: mealStatus?.fatGrams ?? 0,
              proteinGrams: mealStatus?.proteinGrams ?? 0,
            )
            .withSchedule(
              settings.copyWith(
                deliveryMode: ExtendedCarbsDeliveryMode.extendedCarbs,
              ),
            );
      }
      state = state.copyWith(
        skipMeal: false,
        step: MealDialogStep.confirm,
        carbsGrams: carbs,
        extendedCarbsGrams: extendedCarbs.grams.toDouble(),
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
          extendedCarbs: extendedCarbs,
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
      final expanded = await ref.read(buildMealAdvisorContextUseCaseProvider)(
        context,
        isCancelled: () => !ref.mounted || request != _adviceRequest,
      );
      if (!ref.mounted || request != _adviceRequest) return;
      state = state.copyWith(
        beforeMealContext: context,
        advisorInput: serializeMealAdvisorContext(
          expanded,
          requestId: 'advisor_${context.asOf.microsecondsSinceEpoch}_$request',
        ),
      );
    }
    final resolvedStatus = await ref.read(
      resolveMealAdvisorDeviceStatusUseCaseProvider,
    )();
    if (!ref.mounted || request != _adviceRequest) return;
    final deviceStatus = resolvedStatus.status;
    _adviceDeviceStatus = deviceStatus;
    var unavailableReason =
        resolvedStatus.eligibility == MealAdviceEligibility.available
        ? null
        : resolvedStatus.eligibility;
    var advice = deviceStatus == null || unavailableReason != null
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
      final statusEligibility = ref
          .read(checkMealAdvisorDeviceStatusUseCaseProvider)
          .call(deviceStatus);
      if (eligibility != MealAdviceEligibility.available ||
          statusEligibility != MealAdviceEligibility.available) {
        unavailableReason = eligibility != MealAdviceEligibility.available
            ? eligibility
            : statusEligibility;
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
      unavailableReason: unavailableReason,
      clearUnavailableReason: unavailableReason == null,
      clearActivationBlock: true,
    );
  }

  /// Returns false if the choice changed while its inputs were being checked.
  Future<bool> confirmAdvice() async {
    if (state.isPreparingAdvice) return false;
    final request = _adviceRequest;
    final advice = state.advice;
    final adviceDeviceStatus = _adviceDeviceStatus;
    if (advice.source != 'manual') {
      final checkStatus = ref.read(checkMealAdvisorDeviceStatusUseCaseProvider);
      var unavailableReason = checkStatus(adviceDeviceStatus);
      // A fresh history response must not revive a suggestion calculated on expired inputs.
      if (unavailableReason == MealAdviceEligibility.available) {
        final resolvedStatus = await ref.read(
          resolveMealAdvisorDeviceStatusUseCaseProvider,
        )();
        if (!ref.mounted ||
            request != _adviceRequest ||
            !identical(state.advice, advice)) {
          return false;
        }
        final eligibility = await _checkAdviceEligibility();
        if (!ref.mounted ||
            request != _adviceRequest ||
            !identical(state.advice, advice)) {
          return false;
        }
        final originalStatusEligibility = checkStatus(adviceDeviceStatus);
        final currentStatusEligibility =
            resolvedStatus.eligibility == MealAdviceEligibility.available
            ? checkStatus(resolvedStatus.status)
            : resolvedStatus.eligibility;
        unavailableReason = eligibility != MealAdviceEligibility.available
            ? eligibility
            : originalStatusEligibility != MealAdviceEligibility.available
            ? originalStatusEligibility
            : currentStatusEligibility;
      }
      if (unavailableReason != MealAdviceEligibility.available) {
        state = state.copyWith(
          advice: MealAdvice.empty(),
          extendedCarbsGrams: 0,
          unavailableReason: unavailableReason,
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
      clearUnavailableReason: true,
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
      clearUnavailableReason: true,
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
      clearUnavailableReason: true,
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

  Future<void> cancelPendingAdviceReminder() async {
    final notificationsPluginController = ref.read(
      notificationsControllerUiProvider,
    );
    final event = MealAdvicePendingNotificationEvent(mealId: mealId);
    final id = const HashNotificationIdFactory().create(event.key);

    try {
      await notificationsPluginController.cancel(id);
    } catch (e) {
      logE('Error cancelling pending meal advice reminder: $e');
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
