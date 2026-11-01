import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_advice_pending_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/models/persisted_meal_advisor_result.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/repositories/meal_advisor_result_store.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/available_meal_advice_eligibility.dart';
import '../../../helpers/device_status_factory.dart';

void main() {
  late ProviderContainer container;
  late MealMacroSummary macros;
  late AvailableMealAdviceEligibility eligibility;
  late FakeNotificationsController notifications;
  Meal? blockingMeal;
  Future<Meal?>? pendingActivationCheck;
  final provider = mealDialogControllerProvider(1, MealDialogStep.choose);
  const schedule = ExtendedCarbsScheduleSettings(
    delayMinutes: 30,
    durationMinutes: 90,
  );

  setUp(() {
    eligibility = AvailableMealAdviceEligibility();
    notifications = FakeNotificationsController();
    blockingMeal = null;
    pendingActivationCheck = null;
    macros = MealMacroSummary(
      carbsGrams: 45,
      fatGrams: 10,
      proteinGrams: 7.5,
      fiberGrams: 0,
      totalGrams: 180,
    );
    container = ProviderContainer(
      overrides: [
        checkMealAdviceEligibilityUseCaseProvider.overrideWithValue(
          eligibility,
        ),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        mealBlockingActivationProvider(1).overrideWith(
          (ref) async => pendingActivationCheck == null
              ? blockingMeal
              : await pendingActivationCheck!,
        ),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (ref) async => schedule,
        ),
        mealMacronutrientsSummaryProvider(
          1,
        ).overrideWith((ref) async => macros),
      ],
    );
    container.listen(provider, (_, _) {});
    container
        .read(deviceStatusUiProvider.notifier)
        .update(
          testDeviceStatus(
            bg: 180,
            iob: 0,
            cob: 0,
            date: clock.now(),
            tick: '0',
          ),
        );
  });

  tearDown(() => container.dispose());

  for (final decision in [
    MealDecision.bolusAndEatNow,
    MealDecision.eatNowBolusLater,
    MealDecision.bolusWaitThenEat,
  ]) {
    test(
      'changing to $decision preserves reviewed quantities and schedule',
      () async {
        final controller = container.read(provider.notifier);
        await controller.chooseEat();
        final previous = container.read(provider);
        expect(previous.advice.decision, MealDecision.bolusWaitThenEat);
        expect(previous.carbsGrams, 45);
        expect(previous.extendedCarbsGrams, 12);

        // Editing the order is not a new nutrition calculation.
        macros = MealMacroSummary(
          carbsGrams: 90,
          fatGrams: 0,
          proteinGrams: 0,
          fiberGrams: 0,
          totalGrams: 180,
        );
        container.invalidate(mealMacronutrientsSummaryProvider(1));
        final waitMinutes = decision == MealDecision.bolusWaitThenEat ? 8 : 0;
        await controller.chooseEat(
          manual: ManualMealDecision(
            decision: decision,
            waitMinutes: waitMinutes,
          ),
        );

        final updated = container.read(provider);
        expect(updated.advice.decision, decision);
        expect(updated.advice.source, 'manual');
        expect(updated.advice.reason, isNull);
        expect(updated.advice.wait?.recommendedMinutes ?? 0, waitMinutes);
        expect(updated.carbsGrams, 45);
        expect(updated.extendedCarbsGrams, 12);
        expect(
          updated.advice.extendedCarbs,
          same(previous.advice.extendedCarbs),
        );
        expect(updated.advice.extendedCarbs.scheduleSettings.delayMinutes, 30);
        expect(
          updated.advice.extendedCarbs.scheduleSettings.durationMinutes,
          90,
        );
        expect(updated.isPreparingAdvice, isFalse);
        expect(updated.preparationFailed, isFalse);

        final store = PreservedMealAdviceStore()..statuses = [decision.status];
        final persistence = MealAdvisorResultUseCase(store);
        await persistence.saveMealAdvice(1, updated.advice);
        final restored = (await persistence.loadMealAdvice(1))!;
        expect(restored.source, 'manual');
        expect(restored.decision, decision);
        expect(restored.extendedCarbs.grams, 12);
        expect(restored.extendedCarbs.scheduleSettings.delayMinutes, 30);
        expect(restored.extendedCarbs.scheduleSettings.durationMinutes, 90);
      },
    );
  }

  test('repeated decision edits retain the original extended carbs', () async {
    final controller = container.read(provider.notifier);
    await controller.chooseEat();
    final extendedCarbs = container.read(provider).advice.extendedCarbs;
    await controller.chooseEat(manual: const ManualMealDecision());
    await controller.chooseEat(
      manual: const ManualMealDecision(
        decision: MealDecision.bolusWaitThenEat,
        waitMinutes: 10,
      ),
    );
    expect(container.read(provider).carbsGrams, 45);
    expect(container.read(provider).extendedCarbsGrams, 12);
    expect(container.read(provider).advice.extendedCarbs, same(extendedCarbs));
    expect(container.read(provider).advice.wait!.recommendedMinutes, 10);
  });

  test(
    'manual choice remains available after automatic advice is unavailable',
    () async {
      eligibility.result = MealAdviceEligibility.staleReadings;
      final controller = container.read(provider.notifier);
      await controller.chooseEat();
      expect(container.read(provider).advice.decision, isNull);
      await controller.chooseEat(
        manual: const ManualMealDecision(
          decision: MealDecision.bolusWaitThenEat,
          waitMinutes: 6,
        ),
      );
      final state = container.read(provider);
      expect(state.advice.source, 'manual');
      expect(state.advice.decision, MealDecision.bolusWaitThenEat);
      expect(state.advice.wait!.recommendedMinutes, 6);
      expect(state.carbsGrams, 45);
      expect(state.preparationFailed, isFalse);
    },
  );

  test(
    'changing a prepared decision still checks for another active meal',
    () async {
      final controller = container.read(provider.notifier);
      await controller.chooseEat();
      final previous = container.read(provider).advice;
      blockingMeal = const Meal(id: 2, name: 'Active meal', status: 'eating');
      container.invalidate(mealBlockingActivationProvider(1));
      await controller.chooseEat(manual: const ManualMealDecision());
      final state = container.read(provider);
      expect(state.step, MealDialogStep.choose);
      expect(state.activationBlockedByMealName, 'Active meal');
      expect(state.advice, same(previous));
      expect(state.extendedCarbsGrams, 12);
      expect(state.isPreparingAdvice, isFalse);
    },
  );

  for (final action in ['skip', 'back']) {
    test('pending manual change cannot overwrite $action', () async {
      final controller = container.read(provider.notifier);
      await controller.chooseEat();
      final previous = container.read(provider).advice;
      final activation = Completer<Meal?>();
      pendingActivationCheck = activation.future;
      container.invalidate(mealBlockingActivationProvider(1));
      final changing = controller.chooseEat(manual: const ManualMealDecision());
      if (action == 'skip') {
        controller.chooseSkip();
      } else {
        controller.back();
      }
      activation.complete(null);
      await changing;
      final state = container.read(provider);
      expect(
        state.step,
        action == 'skip' ? MealDialogStep.confirm : MealDialogStep.choose,
      );
      expect(state.skipMeal, action == 'skip');
      expect(state.advice, same(previous));
      expect(state.extendedCarbsGrams, 12);
      expect(state.isPreparingAdvice, isFalse);
    });
  }

  test(
    'editing preserves an existing extra-bolus delivery mode through persistence',
    () async {
      const extendedCarbs = WbtExtendedCarbsSuggestion(
        kcal: 120,
        wbt: 1.2,
        grams: 12,
        scheduleSettings: ExtendedCarbsScheduleSettings(
          deliveryMode: ExtendedCarbsDeliveryMode.extraBolus,
          delayMinutes: 30,
          durationMinutes: 90,
        ),
      );
      final seeded = ProviderContainer(
        overrides: [
          provider.overrideWith(
            () => SeededMealDialogController(extendedCarbs),
          ),
          mealBlockingActivationProvider(1).overrideWith((ref) async => null),
        ],
      );
      addTearDown(seeded.dispose);
      seeded.listen(provider, (_, _) {});
      await seeded
          .read(provider.notifier)
          .chooseEat(manual: const ManualMealDecision());
      final advice = seeded.read(provider).advice;
      expect(advice.extendedCarbs, same(extendedCarbs));
      expect(seeded.read(provider).extendedCarbsGrams, 12);
      final store = PreservedMealAdviceStore()
        ..statuses = ['waiting-for-bolus'];
      final persistence = MealAdvisorResultUseCase(store);
      await persistence.saveMealAdvice(1, advice);
      final restored = (await persistence.loadMealAdvice(1))!;
      expect(restored.decision, MealDecision.bolusAndEatNow);
      expect(restored.extendedCarbs.grams, 12);
      expect(
        restored.extendedCarbs.scheduleSettings.deliveryMode,
        ExtendedCarbsDeliveryMode.extraBolus,
      );
      expect(restored.extendedCarbs.scheduleSettings.delayMinutes, 30);
      expect(restored.extendedCarbs.scheduleSettings.durationMinutes, 90);
    },
  );

  test('cancelling a pending reminder targets only the current meal', () async {
    const otherMeal = MealAdvicePendingNotificationEvent(mealId: 2);
    await notifications.schedule(otherMeal, const Duration(minutes: 2));
    final controller = container.read(provider.notifier);
    await controller.chooseEat();
    expect(notifications.scheduledEvents, hasLength(2));
    await controller.cancelPendingAdviceReminder();
    expect(notifications.cancelledIds, [
      const HashNotificationIdFactory().create(
        const MealAdvicePendingNotificationEvent(mealId: 1).key,
      ),
    ]);
    expect(notifications.cancelAllCalled, isFalse);
  });

  test(
    'a reminder cancellation error does not prevent returning to the choice',
    () async {
      final controller = container.read(provider.notifier);
      await controller.chooseEat();
      notifications.enqueueCancelError(StateError('Notification unavailable'));
      await controller.cancelPendingAdviceReminder();
      controller.back();
      expect(container.read(provider).step, MealDialogStep.choose);
      expect(notifications.cancelAllCalled, isFalse);
    },
  );

  test(
    'manual choice without prepared advice still loads meal quantities',
    () async {
      final controller = container.read(provider.notifier);
      await controller.chooseEat(manual: const ManualMealDecision());
      final state = container.read(provider);
      expect(state.step, MealDialogStep.confirm);
      expect(state.advice.decision, MealDecision.bolusAndEatNow);
      expect(state.advice.source, 'manual');
      expect(state.carbsGrams, 45);
      expect(state.extendedCarbsGrams, 12);
      expect(state.preparationFailed, isFalse);
    },
  );
}

class PreservedMealAdviceStore implements MealAdvisorResultStore {
  PersistedMealAdvisorResult? result;
  List<String> statuses = [];

  @override
  Future<List<String>> getMealStatusHistory(int mealId) async => statuses;

  @override
  Future<PersistedMealAdvisorResult?> getMealAdvisorResult(int mealId) async =>
      result;

  @override
  Future<int> insertMealAdvisorResult(PersistedMealAdvisorResult value) async {
    result = value;
    return 1;
  }
}

class SeededMealDialogController extends MealDialogController {
  SeededMealDialogController(this.extendedCarbs);

  final WbtExtendedCarbsSuggestion extendedCarbs;

  @override
  MealDialogState build(int mId, MealDialogStep initialStep) => super
      .build(mId, initialStep)
      .copyWith(
        step: MealDialogStep.confirm,
        carbsGrams: 45,
        extendedCarbsGrams: extendedCarbs.grams.toDouble(),
        advice: MealAdvice(
          MealDecision.bolusWaitThenEat,
          WaitSuggestion(15, 10, 20),
          extendedCarbs: extendedCarbs,
        ),
      );
}
