import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_advice_pending_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_snapshot_controller.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog_result.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../helpers/device_status_factory.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('eat choice schedules pending advice reminder', (tester) async {
    final notifications = FakeNotificationsController();
    final meal = Meal(
      id: 1,
      status: 'planned',
      name: 'Obiad',
      plannedAt: DateTime(2026, 3, 23, 12, 20),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealBlockingActivationProvider(1).overrideWith((ref) async => null),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          mealMacronutrientsSummaryProvider(1).overrideWithValue(
            AsyncData(
              MealMacroSummary(
                fatGrams: 4,
                proteinGrams: 8,
                fiberGrams: 0,
                carbsGrams: 20,
                totalGrams: 80,
              ),
            ),
          ),
        ],
        child: MaterialApp(home: MealStatusDialog(meal: meal)),
      ),
    );

    _setDeviceStatus(tester);

    await tester.tap(find.text('Zjem'));
    await tester.pumpAndSettle();

    expect(notifications.scheduledEvents, hasLength(1));
    final scheduled = notifications.scheduledEvents.single;
    expect(scheduled.event, isA<MealAdvicePendingNotificationEvent>());
    expect(scheduled.duration, MealDialogController.pendingAdviceReminderDelay);
    expect(find.text('Podaje bolusa'), findsOneWidget);
  });

  testWidgets('accepting advice cancels meal notifications', (tester) async {
    final notifications = FakeNotificationsController();
    final meal = Meal(
      id: 1,
      status: 'planned',
      name: 'Obiad',
      plannedAt: DateTime(2026, 3, 23, 12, 20),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealBlockingActivationProvider(1).overrideWith((ref) async => null),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          mealMacronutrientsSummaryProvider(1).overrideWithValue(
            AsyncData(
              MealMacroSummary(
                fatGrams: 4,
                proteinGrams: 8,
                fiberGrams: 0,
                carbsGrams: 20,
                totalGrams: 80,
              ),
            ),
          ),
          insertAdviceProvider.overrideWith((ref, args) async {}),
          mealSnapshotControllerProvider.overrideWith(
            (ref) => _NoopMealSnapshotController(ref: ref),
          ),
        ],
        child: MaterialApp(home: MealStatusDialog(meal: meal)),
      ),
    );

    _setDeviceStatus(tester);

    await tester.tap(find.text('Zjem'));
    await tester.pumpAndSettle();
    expect(notifications.scheduledEvents, hasLength(1));

    await tester.tap(find.text('Podaje bolusa'));
    await tester.pumpAndSettle();

    expect(notifications.cancelAllCalled, isTrue);
    expect(notifications.scheduledEvents, hasLength(1));
    expect(
      notifications.scheduledEvents.single.event,
      isA<MealAdvicePendingNotificationEvent>(),
    );
  });

  testWidgets('cancelling advice cancels meal notifications', (tester) async {
    final notifications = FakeNotificationsController();
    final meal = Meal(
      id: 1,
      status: 'planned',
      name: 'Obiad',
      plannedAt: DateTime(2026, 3, 23, 12, 20),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealBlockingActivationProvider(1).overrideWith((ref) async => null),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          mealMacronutrientsSummaryProvider(1).overrideWithValue(
            AsyncData(
              MealMacroSummary(
                fatGrams: 4,
                proteinGrams: 8,
                fiberGrams: 0,
                carbsGrams: 20,
                totalGrams: 80,
              ),
            ),
          ),
        ],
        child: MaterialApp(home: MealStatusDialog(meal: meal)),
      ),
    );

    _setDeviceStatus(tester);

    await tester.tap(find.text('Zjem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(notifications.cancelAllCalled, isTrue);
  });

  testWidgets('cancelling skip confirmation does not cancel notifications', (
    tester,
  ) async {
    final notifications = FakeNotificationsController();
    final meal = Meal(
      id: 1,
      status: 'planned',
      name: 'Obiad',
      plannedAt: DateTime(2026, 3, 23, 12, 20),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsControllerUiProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(home: MealStatusDialog(meal: meal)),
      ),
    );

    await tester.tap(find.text('Pomijam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(notifications.cancelAllCalled, isFalse);
  });

  testWidgets('waiting for bolus can cancel meal', (tester) async {
    final notifications = FakeNotificationsController();
    final meal = Meal(
      id: 1,
      status: 'waiting-for-bolus',
      name: 'Obiad',
      plannedAt: DateTime(2026, 3, 23, 12, 20),
    );
    Object? dialogResult;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsControllerUiProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                dialogResult = await showDialog<Object?>(
                  context: context,
                  builder: (context) => MealStatusDialog(meal: meal),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Czekamy na bolus z kalkulatora.'), findsOneWidget);
    expect(find.text('Anuluj posiłek'), findsOneWidget);

    await tester.tap(find.text('Anuluj posiłek'));
    await tester.pumpAndSettle();

    expect(notifications.cancelAllCalled, isTrue);
    expect(dialogResult, isA<MealStatusUpdateResult>());
    expect((dialogResult as MealStatusUpdateResult).status, 'skipped');
  });
}

class _NoopMealSnapshotController extends MealSnapshotController {
  _NoopMealSnapshotController({required super.ref});

  @override
  Future<void> createPlannedSnapshot(int mealId) async {}
}

void _setDeviceStatus(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MealStatusDialog)),
  );
  container
      .read(deviceStatusUiProvider.notifier)
      .update(
        testDeviceStatus(
          bg: 120,
          iob: 0,
          cob: 0,
          date: DateTime(2026, 3, 23, 12, 0),
          tick: '',
        ),
      );
}
