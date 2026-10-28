import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/meal_advisor_context_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_target.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/build_meal_advisor_context_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/check_meal_advice_eligibility_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_analysis/data/providers/build_before_meal_context_use_case_provider.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/device_status_factory.dart';

class CountingAdviceEligibility extends CheckMealAdviceEligibilityUseCase {
  CountingAdviceEligibility()
    : super(loadRepository: () => throw UnimplementedError());
  int calls = 0;
  Future<MealAdviceEligibility>? pending;
  @override
  Future<MealAdviceEligibility> call() async {
    calls++;
    return pending == null ? MealAdviceEligibility.available : await pending!;
  }
}

class AssistedAdvisorFixture {
  final now = clock.now();
  final gate = Completer<void>();
  final started = Completer<void>();
  final eligibility = CountingAdviceEligibility();
  final notifications = FakeNotificationsController();
  late final ProviderContainer container;
  int contextCalls = 0;
  final provider = mealDialogControllerProvider(1, MealDialogStep.choose);

  List<Glucose> readings({int ageMinutes = 0}) => [
    for (final age in [10, 5, 0])
      Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: now.subtract(Duration(minutes: age + ageMinutes)),
        sgv: 120,
        direction: 'Flat',
      ),
  ];

  AssistedAdvisorFixture({required bool assisted, bool cache = true}) {
    container = ProviderContainer(
      overrides: [
        aiAssistedMealAdvisorEnabledProvider.overrideWithValue(assisted),
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
        buildMealAdvisorContextUseCaseProvider.overrideWith((ref) {
          if (!assisted) {
            throw StateError(
              'Regular advisor must not initialize extended advisor context',
            );
          }
          return BuildMealAdvisorContextUseCase(
            now: clock.now,
            loadTarget: (before) async => MealAdvisorTarget(
              mealId: before.mealId!,
              name: 'Planned meal',
              plannedAt: before.asOf,
              macros: before.macros!,
              composition: null,
              confidence: null,
              ingredients: [],
            ),
            findSimilar: (target, asOf) async => SimilarMealContext(
              asOf: asOf,
              searchStart: asOf.subtract(const Duration(days: 90)),
              target: target.macros,
              matches: [],
            ),
            loadHistorical: (_, _) =>
                throw StateError('No historical comparisons in this fixture'),
          );
        }),
        buildBeforeMealContextUseCaseProvider(false).overrideWith((ref) {
          if (!assisted) {
            throw StateError(
              'Regular advisor must not initialize the context builder',
            );
          }
          return BuildBeforeMealContextUseCase(
            loadGlucose: (_, _) async {
              contextCalls++;
              if (!started.isCompleted) started.complete();
              await gate.future;
              return readings();
            },
            loadDeviceStatuses: (_, _) async => [],
            loadTreatments: (_, _) async => [],
            loadMeals: (_, _, _) async => [],
            loadLowTreatments: (_, _) async => [],
            loadActivities: (_, _, _) async => [],
            loadPodAge: (_) async => null,
            now: clock.now,
          );
        }),
      ],
    );
    container.listen(provider, (_, _) {});
    container
        .read(deviceStatusUiProvider.notifier)
        .update(
          testDeviceStatus(date: now, iob: 0, cob: 0, tick: '0', bg: 120),
        );
    if (cache) {
      container
          .read(bloodSugarReadingsListProvider.notifier)
          .replaceAll(readings());
    }
  }
  MealDialogController get controller => container.read(provider.notifier);
  MealDialogState get state => container.read(provider);
  void dispose() => container.dispose();
}

void main() {
  test(
    'regular advisor uses fresh displayed CGM and never initializes extended context',
    () async {
      final fixture = AssistedAdvisorFixture(assisted: false);
      addTearDown(fixture.dispose);
      await fixture.controller.chooseEat();
      expect(fixture.state.advice.decision, isNotNull);
      expect(fixture.state.beforeMealContext, isNull);
      expect(fixture.state.isAiAssisted, isFalse);
      expect(fixture.contextCalls, 0);
      expect(fixture.eligibility.calls, 0);
      expect(fixture.state.isPreparingAdvice, isFalse);
    },
  );

  test(
    'assisted mode always prepares context before showing its existing-rule result',
    () async {
      final fixture = AssistedAdvisorFixture(assisted: true);
      addTearDown(fixture.dispose);
      final choosing = fixture.controller.chooseEat();
      await fixture.started.future;
      expect(fixture.state.isPreparingAdvice, isTrue);
      expect(fixture.state.isAiAssisted, isTrue);
      expect(fixture.state.beforeMealContext, isNull);
      expect(await fixture.controller.confirmAdvice(), isFalse);
      expect(fixture.notifications.scheduledEvents, isEmpty);
      fixture.gate.complete();
      await choosing;
      expect(fixture.state.isPreparingAdvice, isFalse);
      expect(fixture.state.beforeMealContext?.mealId, 1);
      expect(fixture.state.advisorInput?.context.target?.mealId, 1);
      expect(fixture.state.advisorInput?.context.failures, isEmpty);
      expect(fixture.state.advice.decision, isNotNull);
    },
  );

  test(
    'manual choice stops visible loading and a late context cannot overwrite it',
    () async {
      final fixture = AssistedAdvisorFixture(assisted: true);
      addTearDown(fixture.dispose);
      final choosing = fixture.controller.chooseEat();
      await fixture.started.future;
      fixture.controller.cancelAdvicePreparation();
      expect(fixture.state.isPreparingAdvice, isFalse);
      await fixture.controller.chooseEat(
        manual: const ManualMealDecision(waitMinutes: 7),
      );
      final manual = fixture.state.advice;
      fixture.gate.complete();
      await choosing;
      expect(fixture.state.advice, same(manual));
      expect(fixture.state.advice.source, 'manual');
      expect(fixture.state.beforeMealContext, isNull);
      expect(fixture.contextCalls, 1);
      expect(fixture.notifications.scheduledEvents, isEmpty);
    },
  );

  test(
    'closing the dialog during context preparation does not access disposed state',
    () async {
      final fixture = AssistedAdvisorFixture(assisted: true);
      final choosing = fixture.controller.chooseEat();
      await fixture.started.future;
      fixture.dispose();
      fixture.gate.complete();
      await choosing;
      expect(fixture.notifications.scheduledEvents, isEmpty);
    },
  );

  test(
    'stale cached CGM cannot bypass the existing history eligibility check',
    () async {
      final fixture = AssistedAdvisorFixture(assisted: false);
      addTearDown(fixture.dispose);
      fixture.container
          .read(bloodSugarReadingsListProvider.notifier)
          .replaceAll(fixture.readings(ageMinutes: 15));
      fixture.eligibility.pending = Future.value(
        MealAdviceEligibility.staleReadings,
      );
      await fixture.controller.chooseEat();
      expect(fixture.eligibility.calls, 1);
      expect(fixture.state.advice.decision, isNull);
      expect(fixture.state.isPreparingAdvice, isFalse);
    },
  );

  test(
    'cancelling preparation also discards late cloud eligibility results',
    () async {
      final fixture = AssistedAdvisorFixture(assisted: false, cache: false);
      addTearDown(fixture.dispose);
      final response = Completer<MealAdviceEligibility>();
      fixture.eligibility.pending = response.future;
      final choosing = fixture.controller.chooseEat();
      await Future<void>.delayed(Duration.zero);
      expect(fixture.eligibility.calls, 1);
      fixture.controller.cancelAdvicePreparation();
      await fixture.controller.chooseEat(manual: const ManualMealDecision());
      response.complete(MealAdviceEligibility.available);
      await choosing;
      expect(fixture.state.advice.source, 'manual');
      expect(fixture.state.isPreparingAdvice, isFalse);
      expect(fixture.notifications.scheduledEvents, isEmpty);
    },
  );
}
