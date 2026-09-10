import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/available_meal_advice_eligibility.dart';
import '../../../helpers/device_status_factory.dart';

void main() {
  late ProviderContainer container;
  late FakeNotificationsController notifications;
  late AvailableMealAdviceEligibility eligibility;
  final provider = mealDialogControllerProvider(1, MealDialogStep.choose);

  setUp(() {
    notifications = FakeNotificationsController();
    eligibility = AvailableMealAdviceEligibility();
    container = ProviderContainer(
      overrides: [
        checkMealAdviceEligibilityUseCaseProvider.overrideWithValue(
          eligibility,
        ),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        mealBlockingActivationProvider(1).overrideWith((ref) async => null),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (ref) async => const ExtendedCarbsScheduleSettings.defaults(),
        ),
        mealMacronutrientsSummaryProvider(1).overrideWithValue(
          AsyncData(
            MealMacroSummary(
              carbsGrams: 20,
              fatGrams: 0,
              proteinGrams: 0,
              fiberGrams: 0,
              totalGrams: 20,
            ),
          ),
        ),
      ],
    );
    container.listen(provider, (_, _) {});
    container
        .read(deviceStatusUiProvider.notifier)
        .update(
          testDeviceStatus(
            bg: 120,
            iob: 0,
            cob: 0,
            date: clock.now(),
            tick: '0',
          ),
        );
  });
  tearDown(() => container.dispose());

  for (final action in ['skip', 'dispose']) {
    test('pending reminder cannot overwrite $action', () async {
      final scheduled = Completer<void>();
      notifications.enqueueScheduleFuture(scheduled.future);
      final controller = container.read(provider.notifier);
      final choosing = controller.chooseEat();
      // Drain repository/provider microtasks to reach the suspended schedule.
      await Future<void>.delayed(Duration.zero);
      expect(notifications.scheduledEvents, hasLength(1));
      if (action == 'skip') {
        controller.chooseSkip();
      } else {
        container.dispose();
      }
      scheduled.complete();
      await choosing;
      if (action == 'skip') expect(container.read(provider).skipMeal, isTrue);
    });
  }

  for (final result in [
    MealAdviceEligibility.available,
    MealAdviceEligibility.staleReadings,
  ]) {
    test(
      'confirmation cannot save or clear a newer choice after $result',
      () async {
        final controller = container.read(provider.notifier);
        await controller.chooseEat();
        final previous = container.read(provider).advice;
        final validation = Completer<MealAdviceEligibility>();
        eligibility.pendingResult = validation.future;
        final confirming = controller.confirmAdvice();
        controller.chooseSkip();
        validation.complete(result);
        expect(await confirming, isFalse);
        expect(container.read(provider).skipMeal, isTrue);
        expect(container.read(provider).advice, same(previous));
        expect(notifications.cancelAllCalled, isFalse);
      },
    );
  }
  test(
    'automatic validation cannot overwrite a newer manual decision',
    () async {
      final controller = container.read(provider.notifier);
      await controller.chooseEat();
      final validation = Completer<MealAdviceEligibility>();
      eligibility.pendingResult = validation.future;
      final confirming = controller.confirmAdvice();
      await controller.chooseEat(manual: const ManualMealDecision());
      final manual = container.read(provider).advice;
      validation.complete(MealAdviceEligibility.staleReadings);
      expect(await confirming, isFalse);
      expect(container.read(provider).advice, same(manual));
      expect(manual.source, 'manual');
      expect(notifications.cancelAllCalled, isFalse);
    },
  );
}
