import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_advice_pending_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/get_meal_advice_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../foreground/utils/fake_runtime_harness.dart';
import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/nightscout_advice_replay.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scenario in [
    'fresh',
    'missing',
    'gap',
    'stale',
    'expires-while-open',
  ]) {
    testWidgets('Nightscout replay: UI and foreground $scenario', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 1, 1, 12);
      await withClock(Clock(() => now), () async {
        final replay = NightscoutAdviceReplay(now);
        if (scenario == 'missing') replay.readings = [];
        if (scenario == 'gap') {
          replay.readings[1] = replay.readings[1].copyWith(
            date: now.subtract(const Duration(minutes: 10)),
          );
        }
        if (scenario == 'stale') {
          replay.readings = replay.readings
              .map(
                (r) => r.copyWith(
                  date: r.date.subtract(const Duration(minutes: 8)),
                ),
              )
              .toList();
        }
        final notifications = FakeNotificationsController();
        final macros = MealMacroSummary(
          fatGrams: 4,
          proteinGrams: 8,
          fiberGrams: 0,
          carbsGrams: 20,
          totalGrams: 80,
        );
        final meal = Meal(
          id: 1,
          status: 'planned',
          name: 'Posiłek testowy',
          plannedAt: now.add(const Duration(minutes: 20)),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              glucoseHistoryRepositoryProvider.overrideWith(
                (ref) async => replay,
              ),
              notificationsControllerUiProvider.overrideWithValue(
                notifications,
              ),
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              deviceStatusValueProvider.overrideWithValue(replay.status),
              mealBlockingActivationProvider(
                1,
              ).overrideWith((ref) async => null),
              mealMacronutrientsSummaryProvider(
                1,
              ).overrideWithValue(AsyncData(macros)),
            ],
            child: localizedMaterialApp(home: MealStatusDialog(meal: meal)),
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealStatusDialog)),
        );
        container.read(deviceStatusUiProvider.notifier).update(replay.status);
        await tester.tap(find.text('Zjem'));
        await tester.pumpAndSettle();
        final provider = mealDialogControllerProvider(1, MealDialogStep.choose);
        final initiallyAvailable =
            scenario == 'fresh' || scenario == 'expires-while-open';
        expect(
          container.read(provider).advice.decision != null,
          initiallyAvailable,
        );
        final harness = FakeRuntimeHarness(container: container);
        final monitor = MonitorUntilMeal();
        expect(
          await monitor.checkAdviceEligibility(
            harness.runtimeContext,
            1,
            adviceStatus: replay.status,
          ),
          initiallyAvailable,
        );
        if (initiallyAvailable) {
          final shared = container.read(getMealAdviceUseCaseProvider)(
            macros: macros,
            deviceStatus: replay.status,
            settings: const ExtendedCarbsScheduleSettings.defaults(),
          );
          expect(container.read(provider).advice.decision, shared.decision);
          expect(container.read(provider).advice.reason, shared.reason);
        }
        if (scenario == 'expires-while-open') {
          now = now.add(const Duration(minutes: 8));
          // A fresh envelope must not make the original advice or CGM fresh.
          container
              .read(deviceStatusUiProvider.notifier)
              .update(replay.status.copyWith(date: now));
          await expectLater(
            container.read(provider.notifier).confirmAdvice(),
            throwsException,
          );
          await tester.pumpAndSettle();
          expect(
            await monitor.checkAdviceEligibility(
              harness.runtimeContext,
              1,
              adviceStatus: replay.status,
            ),
            isFalse,
          );
        }
        if (!initiallyAvailable || scenario == 'expires-while-open') {
          expect(
            find.textContaining(
              'Brak aktualnych danych do automatycznej porady',
            ),
            findsOneWidget,
          );
          expect(find.byTooltip('Wybierz decyzję ręcznie'), findsOneWidget);
          expect(
            notifications.lastShownEvent,
            isA<MealAdvicePendingNotificationEvent>(),
          );
        }
        expect(tester.takeException(), isNull);
      });
    });
  }
}
