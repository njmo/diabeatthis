import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/resolve_meal_advisor_device_status_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/resolved_meal_advisor_device_status.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/resolve_meal_advisor_device_status_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/available_meal_advice_eligibility.dart';
import '../../../helpers/device_status_factory.dart';
import 'meal_dialog_decision_preservation_test.dart'
    show PreservedMealAdviceStore;

void main() {
  late ProviderContainer container;
  late MealMacroSummary macros;
  late ExtendedCarbsScheduleSettings settings;
  late AvailableMealAdviceEligibility eligibility;
  late ManualFallbackStatusResolver resolver;
  late FakeNotificationsController notifications;
  late Completer<void> settingsStarted;
  Future<ExtendedCarbsScheduleSettings>? pendingSettings;
  late bool disposed;
  final provider = mealDialogControllerProvider(1, MealDialogStep.choose);
  const decisions = [
    MealDecision.bolusAndEatNow,
    MealDecision.eatNowBolusLater,
    MealDecision.bolusWaitThenEat,
  ];

  setUp(() {
    disposed = false;
    macros = MealMacroSummary(
      carbsGrams: 45,
      fatGrams: 10,
      proteinGrams: 7.5,
      fiberGrams: 0,
      totalGrams: 180,
    );
    settings = const ExtendedCarbsScheduleSettings(
      delayMinutes: 30,
      durationMinutes: 90,
    );
    settingsStarted = Completer<void>();
    pendingSettings = null;
    eligibility = AvailableMealAdviceEligibility();
    resolver = ManualFallbackStatusResolver(
      ResolvedMealAdvisorDeviceStatus(
        status: testDeviceStatus(
          bg: 180,
          iob: 0,
          cob: 0,
          date: clock.now(),
          tick: '0',
        ),
        eligibility: MealAdviceEligibility.available,
      ),
    );
    notifications = FakeNotificationsController();
    container = ProviderContainer(
      overrides: [
        aiAssistedMealAdvisorEnabledProvider.overrideWithValue(false),
        checkMealAdviceEligibilityUseCaseProvider.overrideWithValue(
          eligibility,
        ),
        resolveMealAdvisorDeviceStatusUseCaseProvider.overrideWithValue(
          resolver,
        ),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        mealBlockingActivationProvider(1).overrideWith((ref) async => null),
        mealMacronutrientsSummaryProvider(
          1,
        ).overrideWith((ref) async => macros),
        extendedCarbsScheduleSettingsProvider.overrideWith((ref) async {
          if (!settingsStarted.isCompleted) settingsStarted.complete();
          return pendingSettings == null ? settings : await pendingSettings!;
        }),
      ],
    );
    container.listen(provider, (_, _) {});
  });

  tearDown(() {
    if (!disposed) container.dispose();
  });

  for (final decision in decisions) {
    test(
      'direct manual $decision calculates and persists meal eCarbs',
      () async {
        final waitMinutes = decision == MealDecision.bolusWaitThenEat ? 8 : 0;
        await container
            .read(provider.notifier)
            .chooseEat(
              manual: ManualMealDecision(
                decision: decision,
                waitMinutes: waitMinutes,
              ),
            );

        final state = container.read(provider);
        expect(state.step, MealDialogStep.confirm);
        expect(state.skipMeal, isFalse);
        expect(state.carbsGrams, 45);
        expect(state.extendedCarbsGrams, 12);
        expect(state.advice.extendedCarbs.grams, 12);
        expect(state.advice.extendedCarbs.kcal, 120);
        expect(state.advice.extendedCarbs.wbt, 1.2);
        expect(state.advice.extendedCarbs.scheduleSettings.delayMinutes, 30);
        expect(state.advice.extendedCarbs.scheduleSettings.durationMinutes, 90);
        expect(state.advice.decision, decision);
        expect(state.advice.source, 'manual');
        expect(state.advice.reason, isNull);
        expect(state.advice.wait?.recommendedMinutes ?? 0, waitMinutes);
        expect(state.isPreparingAdvice, isFalse);
        expect(state.preparationFailed, isFalse);
        expect(state.unavailableReason, isNull);
        expect(resolver.calls, 0);
        expect(notifications.scheduledEvents, isEmpty);

        final store = PreservedMealAdviceStore()..statuses = [decision.status];
        final persistence = MealAdvisorResultUseCase(store);
        await persistence.saveMealAdvice(1, state.advice);
        final restored = (await persistence.loadMealAdvice(1))!;
        expect(restored.source, 'manual');
        expect(restored.decision, decision);
        expect(restored.wait?.recommendedMinutes ?? 0, waitMinutes);
        expect(restored.extendedCarbs.grams, 12);
        expect(
          restored.extendedCarbs.scheduleSettings.deliveryMode,
          ExtendedCarbsDeliveryMode.extendedCarbs,
        );
        expect(restored.extendedCarbs.scheduleSettings.delayMinutes, 30);
        expect(restored.extendedCarbs.scheduleSettings.durationMinutes, 90);
      },
    );
  }

  for (final reason in [
    MealAdviceEligibility.missingDeviceStatus,
    MealAdviceEligibility.historyUnavailable,
    MealAdviceEligibility.staleReadings,
  ]) {
    test('manual fallback after $reason recovers meal eCarbs', () async {
      if (reason == MealAdviceEligibility.staleReadings) {
        eligibility.result = reason;
      } else {
        resolver.result = ResolvedMealAdvisorDeviceStatus(eligibility: reason);
      }
      final controller = container.read(provider.notifier);
      await controller.chooseEat();
      expect(container.read(provider).advice.decision, isNull);
      expect(container.read(provider).unavailableReason, reason);

      await controller.chooseEat(manual: const ManualMealDecision());
      final state = container.read(provider);
      expect(state.advice.source, 'manual');
      expect(state.advice.decision, MealDecision.bolusAndEatNow);
      expect(state.carbsGrams, 45);
      expect(state.extendedCarbsGrams, 12);
      expect(state.advice.extendedCarbs.grams, 12);
      expect(state.advice.extendedCarbs.scheduleSettings.delayMinutes, 30);
      expect(state.advice.extendedCarbs.scheduleSettings.durationMinutes, 90);
      expect(state.unavailableReason, isNull);
      expect(state.preparationFailed, isFalse);
      expect(resolver.calls, 1);
      expect(notifications.scheduledEvents, isEmpty);
    });
  }

  test('canceled automatic preparation cannot replace manual eCarbs', () async {
    final response = Completer<ResolvedMealAdvisorDeviceStatus>();
    resolver.pending = response.future;
    final controller = container.read(provider.notifier);
    final automaticChoice = controller.chooseEat();
    await resolver.started.future;

    controller.cancelAdvicePreparation();
    await controller.chooseEat(manual: const ManualMealDecision());
    final manualState = container.read(provider);
    expect(manualState.extendedCarbsGrams, 12);
    expect(manualState.advice.extendedCarbs.grams, 12);
    expect(manualState.advice.source, 'manual');

    response.complete(resolver.result);
    await automaticChoice;
    expect(container.read(provider), same(manualState));
    expect(notifications.scheduledEvents, isEmpty);
  });

  test(
    'repeated manual edits preserve the first calculated meal and schedule',
    () async {
      final controller = container.read(provider.notifier);
      await controller.chooseEat(manual: const ManualMealDecision());
      final original = container.read(provider).advice.extendedCarbs;
      macros = MealMacroSummary(
        carbsGrams: 90,
        fatGrams: 0,
        proteinGrams: 0,
        fiberGrams: 0,
        totalGrams: 180,
      );
      settings = const ExtendedCarbsScheduleSettings(
        delayMinutes: 60,
        durationMinutes: 180,
      );
      container.invalidate(mealMacronutrientsSummaryProvider(1));
      container.invalidate(extendedCarbsScheduleSettingsProvider);

      for (final decision in decisions.reversed) {
        await controller.chooseEat(
          manual: ManualMealDecision(
            decision: decision,
            waitMinutes: decision == MealDecision.bolusWaitThenEat ? 10 : 0,
          ),
        );
        final state = container.read(provider);
        expect(state.advice.decision, decision);
        expect(state.carbsGrams, 45);
        expect(state.extendedCarbsGrams, 12);
        expect(state.advice.extendedCarbs, same(original));
        expect(state.advice.extendedCarbs.scheduleSettings.delayMinutes, 30);
        expect(state.advice.extendedCarbs.scheduleSettings.durationMinutes, 90);
      }
    },
  );

  test(
    'new manual premeal advice uses extended carbs delivery with the saved schedule',
    () async {
      settings = const ExtendedCarbsScheduleSettings(
        deliveryMode: ExtendedCarbsDeliveryMode.extraBolus,
        delayMinutes: 35,
        durationMinutes: 100,
      );
      await container
          .read(provider.notifier)
          .chooseEat(manual: const ManualMealDecision());
      final extendedCarbs = container.read(provider).advice.extendedCarbs;
      expect(extendedCarbs.grams, 12);
      expect(
        extendedCarbs.scheduleSettings.deliveryMode,
        ExtendedCarbsDeliveryMode.extendedCarbs,
      );
      expect(extendedCarbs.scheduleSettings.delayMinutes, 35);
      expect(extendedCarbs.scheduleSettings.durationMinutes, 100);
    },
  );

  for (final nutrition in [
    (fat: 5.0, protein: 5.0),
    (fat: 8.0, protein: 7.0),
  ]) {
    test(
      'manual meal at or below the eCarbs threshold stays zero: $nutrition',
      () async {
        macros = MealMacroSummary(
          carbsGrams: 45,
          fatGrams: nutrition.fat,
          proteinGrams: nutrition.protein,
          fiberGrams: 0,
          totalGrams: 180,
        );
        await container
            .read(provider.notifier)
            .chooseEat(manual: const ManualMealDecision());
        final state = container.read(provider);
        expect(state.carbsGrams, 45);
        expect(state.extendedCarbsGrams, 0);
        expect(state.advice.extendedCarbs.grams, 0);
        expect(state.advice.extendedCarbs.shouldSuggest, isFalse);
        expect(state.advice.source, 'manual');
        expect(state.preparationFailed, isFalse);
      },
    );
  }

  for (final action in ['skip', 'back', 'cancel', 'dispose']) {
    test('late manual schedule cannot overwrite $action', () async {
      final response = Completer<ExtendedCarbsScheduleSettings>();
      pendingSettings = response.future;
      final controller = container.read(provider.notifier);
      final choosing = controller.chooseEat(manual: const ManualMealDecision());
      await settingsStarted.future;

      switch (action) {
        case 'skip':
          controller.chooseSkip();
        case 'back':
          controller.back();
        case 'cancel':
          controller.cancelAdvicePreparation();
        case 'dispose':
          container.dispose();
          disposed = true;
      }
      final stateAfterAction = disposed ? null : container.read(provider);
      response.complete(settings);
      await choosing;

      expect(notifications.scheduledEvents, isEmpty);
      if (disposed) return;
      final state = container.read(provider);
      expect(state, same(stateAfterAction));
      expect(state.isPreparingAdvice, isFalse);
      expect(state.advice.decision, isNull);
      expect(state.extendedCarbsGrams, 0);
      expect(state.skipMeal, action == 'skip');
      expect(
        state.step,
        action == 'back' ? MealDialogStep.choose : MealDialogStep.confirm,
      );
    });
  }
}

class ManualFallbackStatusResolver
    extends ResolveMealAdvisorDeviceStatusUseCase {
  ManualFallbackStatusResolver(this.result)
    : super(
        loadRepository: () => throw UnimplementedError(),
        readCurrentStatus: () => null,
      );

  ResolvedMealAdvisorDeviceStatus result;
  Future<ResolvedMealAdvisorDeviceStatus>? pending;
  final started = Completer<void>();
  int calls = 0;

  @override
  Future<ResolvedMealAdvisorDeviceStatus> call() async {
    calls++;
    if (!started.isCompleted) started.complete();
    return pending == null ? result : await pending!;
  }
}
