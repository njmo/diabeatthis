import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_progress/active_meal_add_on_bolus_action.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../helpers/localized_material_app.dart';

void main() {
  late DatabaseImpl db;
  late int mealId;
  late ProviderContainer container;
  late AddOnReopenLauncher launcher;
  late FakeNotificationsController notifications;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    mealId = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Meal with an extra meatball',
            plannedAt: 1,
            status: const Value('eating-extra'),
          ),
        );
    launcher = AddOnReopenLauncher();
    notifications = FakeNotificationsController();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        aapsLauncherProvider.overrideWithValue(launcher),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (_) async => const ExtendedCarbsScheduleSettings.defaults(),
        ),
      ],
    );
    container.read(databaseProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> saveContext({required int carbs, int extendedCarbs = 0}) async {
    final context = MealAddOnBolusContext(
      originalStatus: 'bolused-eating',
      eatingStartedAt: DateTime(2026, 11, 2, 12),
      requestedAt: DateTime(2026, 11, 2, 12, 15),
      coveredCarbs: 30,
      statusCoveredCarbs: 30,
      reportedExtendedCarbs: extendedCarbs,
      requestedCarbs: carbs,
      requestedExtendedCarbs: extendedCarbs,
      awaitingBolus: carbs > 0,
      bolusConfirmed: true,
    );
    await (db.update(db.meal)..where((row) => row.id.equals(mealId))).write(
      MealCompanion(addOnBolusContext: Value(context.encode())),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(body: ActiveMealAddOnBolusAction(mealId: mealId)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pending add-on remains reachable after returning to the dashboard',
    (tester) async {
      await saveContext(carbs: 5, extendedCarbs: 11);
      await open(tester);
      expect(find.text('Czekamy na bolus z kalkulatora.'), findsOneWidget);
      await tester.tap(find.text('Otwórz kalkulator'));
      await tester.pumpAndSettle();
      expect(launcher.opens, 1);
      final event =
          notifications.shownEvents.single
              as AapsBolusSuggestionNotificationEvent;
      expect(event.carbs, 5);
      expect(event.extendedCarbs, 11);
      expect(event.extendedCarbsAreAdditional, isTrue);
      final meal = (await db.mealDao.getMealById(mealId))!;
      expect(meal.status, 'eating-extra');
      expect(
        MealAddOnBolusContext.decode(meal.addOnBolusContext)!.awaitingBolus,
        isTrue,
      );
    },
  );

  testWidgets('eCarbs-only instructions do not claim an unconfirmed bolus', (
    tester,
  ) async {
    await saveContext(carbs: 0, extendedCarbs: 11);
    await open(tester);
    expect(find.text('Czekamy na bolus z kalkulatora.'), findsNothing);
    expect(find.text('Instrukcja dla dodatkowych eCarbs'), findsOneWidget);
    await tester.tap(find.text('Otwórz kalkulator'));
    await tester.pumpAndSettle();
    final event =
        notifications.shownEvents.single
            as AapsBolusSuggestionNotificationEvent;
    expect(event.carbs, 0);
    expect(event.extendedCarbs, 11);
  });

  testWidgets('completed instructions leave no duplicate calculator action', (
    tester,
  ) async {
    await saveContext(carbs: 0);
    await open(tester);
    expect(find.text('Otwórz kalkulator'), findsNothing);
    expect(notifications.shownEvents, isEmpty);
  });
}

class AddOnReopenLauncher extends AapsLauncher {
  int opens = 0;
  @override
  Future<AapsLaunchResult> openAaps() async {
    opens++;
    return AapsLaunchResult.opened;
  }
}
