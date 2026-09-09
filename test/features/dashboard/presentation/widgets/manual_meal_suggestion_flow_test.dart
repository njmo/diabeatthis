import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/base/notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';
import '../../../../helpers/localized_material_app.dart';
import '../../../meals/data/domain/use_cases/add_meal_transaction_test.dart'
    show transactionMealDraft;

void main() {
  testWidgets(
    'manual icon appears only at suggestion and editing does not save advice',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerUiProvider.overrideWithValue(
            SilentMealNotifications(),
          ),
          extendedCarbsScheduleSettingsProvider.overrideWith(
            (ref) async => const ExtendedCarbsScheduleSettings.defaults(),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final meal = (await tester.runAsync(
        () =>
            container.read(addMealUseCaseProvider).call(transactionMealDraft()),
      ))!;
      container
          .read(deviceStatusUiProvider.notifier)
          .update(
            testDeviceStatus(
              date: DateTime.now(),
              iob: 0,
              cob: 0,
              tick: '0',
              bg: 140,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(body: MealStatusDialog(meal: meal)),
          ),
        ),
      );
      expect(find.byTooltip('Wybierz decyzję ręcznie'), findsNothing);
      await tester.runAsync(
        () => container
            .read(
              mealDialogControllerProvider(
                meal.id,
                MealDialogStep.choose,
              ).notifier,
            )
            .chooseEat(),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Wybierz decyzję ręcznie'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.mealAdvisorResult).get()),
        isEmpty,
      );
      await tester.tap(find.byTooltip('Wybierz decyzję ręcznie'));
      await tester.pumpAndSettle();
      expect(find.text('Wybierz samodzielnie'), findsOneWidget);
      await tester.tap(find.text('Anuluj').last);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => container
            .read(
              mealDialogControllerProvider(
                meal.id,
                MealDialogStep.choose,
              ).notifier,
            )
            .chooseEat(
              manual: const ManualMealDecision(
                decision: MealDecision.bolusWaitThenEat,
                waitMinutes: 8,
              ),
            ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Decyzja ręczna'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.mealAdvisorResult).get()),
        isEmpty,
      );
      expect(
        (await tester.runAsync(() => db.mealDao.getMealById(meal.id)))!.status,
        'planned',
      );
      await tester.runAsync(
        () => container
            .read(
              mealDialogControllerProvider(
                meal.id,
                MealDialogStep.choose,
              ).notifier,
            )
            .confirmAdvice(),
      );
      final decision = (await tester.runAsync(
        () => db.select(db.mealAdvisorResult).get(),
      ))!.single;
      expect(decision.result, 'manual');
      expect(decision.version, isNull);
      expect(decision.initialWaitTime, 8);
      expect(
        (await tester.runAsync(() => db.mealDao.getMealById(meal.id)))!.status,
        'waiting-for-bolus',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class SilentMealNotifications implements NotificationsController {
  @override
  Future<void> init() async {}
  @override
  Future<void> show(NotificationEvent event) async {}
  @override
  Future<void> schedule(NotificationEvent event, Duration when) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<Iterable<int>> get pending async => [];
}
