import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/resolve_meal_advisor_device_status_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/resolved_meal_advisor_device_status.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/available_meal_advice_eligibility.dart';
import '../../../helpers/device_status_factory.dart';
import 'meal_dialog_manual_ecarbs_test.dart' show ManualFallbackStatusResolver;

void main() {
  late ProviderContainer container;
  late MealMacroSummary? macros;
  late FakeNotificationsController notifications;
  late ManualFallbackStatusResolver resolver;
  final provider = mealDialogControllerProvider(1, MealDialogStep.choose);

  setUp(() {
    macros = null;
    notifications = FakeNotificationsController();
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
    container = ProviderContainer(
      overrides: [
        aiAssistedMealAdvisorEnabledProvider.overrideWithValue(false),
        checkMealAdviceEligibilityUseCaseProvider.overrideWithValue(
          AvailableMealAdviceEligibility(),
        ),
        resolveMealAdvisorDeviceStatusUseCaseProvider.overrideWithValue(
          resolver,
        ),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        mealBlockingActivationProvider(1).overrideWith((ref) async => null),
        mealMacronutrientsSummaryProvider(
          1,
        ).overrideWith((ref) async => macros),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (ref) async => const ExtendedCarbsScheduleSettings(
            delayMinutes: 30,
            durationMinutes: 90,
          ),
        ),
      ],
    );
    container.listen(provider, (_, _) {});
  });

  tearDown(() => container.dispose());

  for (final manual in [null, const ManualMealDecision()]) {
    final source = manual == null ? 'automatic' : 'manual';

    test(
      '$source preparation rejects missing nutrition instead of assuming zero',
      () async {
        await container.read(provider.notifier).chooseEat(manual: manual);

        final state = container.read(provider);
        expect(state.step, MealDialogStep.confirm);
        expect(state.isPreparingAdvice, isFalse);
        expect(state.preparationFailed, isTrue);
        expect(state.advice.decision, isNull);
        expect(state.skipMeal, isFalse);
        expect(state.unavailableReason, isNull);
        expect(resolver.calls, 0);
        expect(notifications.scheduledEvents, isEmpty);
      },
    );

    test('$source preparation accepts known zero nutrition', () async {
      macros = MealMacroSummary(
        carbsGrams: 0,
        fatGrams: 0,
        proteinGrams: 0,
        fiberGrams: 0,
        totalGrams: 0,
      );

      await container.read(provider.notifier).chooseEat(manual: manual);

      final state = container.read(provider);
      expect(state.step, MealDialogStep.confirm);
      expect(state.isPreparingAdvice, isFalse);
      expect(state.preparationFailed, isFalse);
      expect(state.advice.decision, isNotNull);
      expect(state.carbsGrams, 0);
      expect(state.extendedCarbsGrams, 0);
      expect(state.advice.extendedCarbs.grams, 0);
      expect(state.advice.extendedCarbs.shouldSuggest, isFalse);
    });

    test(
      'editing reviewed $source advice preserves quantities when current totals disappear',
      () async {
        macros = MealMacroSummary(
          carbsGrams: 45,
          fatGrams: 10,
          proteinGrams: 7.5,
          fiberGrams: 0,
          totalGrams: 180,
        );
        final controller = container.read(provider.notifier);
        await controller.chooseEat(manual: manual);
        final reviewed = container.read(provider).advice.extendedCarbs;
        expect(reviewed.grams, 12);

        macros = null;
        container.invalidate(mealMacronutrientsSummaryProvider(1));
        await controller.chooseEat(
          manual: const ManualMealDecision(
            decision: MealDecision.eatNowBolusLater,
          ),
        );

        final state = container.read(provider);
        expect(state.advice.decision, MealDecision.eatNowBolusLater);
        expect(state.advice.source, 'manual');
        expect(state.preparationFailed, isFalse);
        expect(state.isPreparingAdvice, isFalse);
        expect(state.carbsGrams, 45);
        expect(state.extendedCarbsGrams, 12);
        expect(state.advice.extendedCarbs, same(reviewed));
        expect(state.advice.extendedCarbs.scheduleSettings.delayMinutes, 30);
        expect(state.advice.extendedCarbs.scheduleSettings.durationMinutes, 90);
      },
    );

    test(
      '$source retry clears the nutrition failure after totals become available',
      () async {
        final controller = container.read(provider.notifier);
        await controller.chooseEat(manual: manual);
        expect(container.read(provider).preparationFailed, isTrue);
        macros = MealMacroSummary(
          carbsGrams: 45,
          fatGrams: 10,
          proteinGrams: 7.5,
          fiberGrams: 0,
          totalGrams: 180,
        );
        container.invalidate(mealMacronutrientsSummaryProvider(1));

        await controller.chooseEat(manual: manual);

        final state = container.read(provider);
        expect(state.preparationFailed, isFalse);
        expect(state.isPreparingAdvice, isFalse);
        expect(state.advice.decision, isNotNull);
        expect(state.carbsGrams, 45);
        expect(state.extendedCarbsGrams, 12);
        expect(state.advice.extendedCarbs.grams, 12);
      },
    );
  }
}
