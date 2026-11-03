import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/get_meal_activity_advice_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_dose_suggestion.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_windows.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/get_meal_activity_advice_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/available_meal_advice_eligibility.dart';
import '../../../helpers/device_status_factory.dart';

class StubMealActivityAdvice extends GetMealActivityAdviceUseCase {
  StubMealActivityAdvice(this.result)
    : super(
        loadWindows: () async => const MealActivityWindows(),
        loadActivities: (_, _) async => [],
        onError: (_, _) {},
      );
  final Future<MealActivityDoseSuggestion?> result;
  DateTime? requestedAt;
  @override
  Future<MealActivityDoseSuggestion?> call({DateTime? mealAt, int? mealId}) {
    requestedAt = mealAt;
    return result;
  }
}

void main() {
  final provider = mealDialogControllerProvider(1, MealDialogStep.choose);
  final now = DateTime(2026, 11, 3, 14);
  final suggestion = MealActivityDoseSuggestion(
    dosePercent: 80,
    activityName: 'Walk',
    startedAt: now.add(const Duration(minutes: 30)),
    phase: MealActivityPhase.upcoming,
  );

  ProviderContainer create(StubMealActivityAdvice activity) {
    final container = ProviderContainer(
      overrides: [
        getMealActivityAdviceUseCaseProvider.overrideWithValue(activity),
        aiAssistedMealAdvisorEnabledProvider.overrideWithValue(false),
        checkMealAdviceEligibilityUseCaseProvider.overrideWithValue(
          AvailableMealAdviceEligibility(),
        ),
        notificationsControllerUiProvider.overrideWithValue(
          FakeNotificationsController(),
        ),
        mealBlockingActivationProvider(1).overrideWith((_) async => null),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (_) async => const ExtendedCarbsScheduleSettings.defaults(),
        ),
        mealMacronutrientsSummaryProvider(1).overrideWithValue(
          AsyncData(
            MealMacroSummary(
              carbsGrams: 45,
              fatGrams: 0,
              proteinGrams: 0,
              fiberGrams: 0,
              totalGrams: 100,
            ),
          ),
        ),
      ],
    );
    container.listen(provider, (_, _) {});
    container
        .read(deviceStatusUiProvider.notifier)
        .update(
          testDeviceStatus(date: now, bg: 120, iob: 0, cob: 0, tick: '0'),
        );
    return container;
  }

  test('controller passes use case proposal into advisor result', () async {
    final activity = StubMealActivityAdvice(Future.value(suggestion));
    final container = create(activity);
    addTearDown(container.dispose);
    await withClock(
      Clock.fixed(now),
      () => container.read(provider.notifier).chooseEat(),
    );
    expect(activity.requestedAt, now);
    expect(
      container.read(provider).advice.activityDoseSuggestion,
      same(suggestion),
    );
    expect(container.read(provider).preparationFailed, isFalse);
  });

  test('late activity response cannot overwrite a newer skip', () async {
    final pending = Completer<MealActivityDoseSuggestion?>();
    final activity = StubMealActivityAdvice(pending.future);
    final container = create(activity);
    addTearDown(container.dispose);
    await withClock(Clock.fixed(now), () async {
      final controller = container.read(provider.notifier);
      final preparing = controller.chooseEat();
      await Future<void>.delayed(Duration.zero);
      expect(activity.requestedAt, now);
      controller.chooseSkip();
      pending.complete(suggestion);
      await preparing;
      expect(container.read(provider).skipMeal, isTrue);
      expect(container.read(provider).advice.activityDoseSuggestion, isNull);
    });
  });

  test(
    'late activity response after disposal does not access controller state',
    () async {
      final pending = Completer<MealActivityDoseSuggestion?>();
      final activity = StubMealActivityAdvice(pending.future);
      final container = create(activity);
      await withClock(Clock.fixed(now), () async {
        final preparing = container.read(provider.notifier).chooseEat();
        await Future<void>.delayed(Duration.zero);
        expect(activity.requestedAt, now);
        container.dispose();
        pending.complete(suggestion);
        await preparing;
      });
    },
  );
}
