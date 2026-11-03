import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller_provider.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../features/meal_summary/domain/use_cases/record_meal_add_on_use_case_test.dart'
    show seedAddOnMeal;
import '../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'automatic meal summary after ordinary carbs keeps e-carbs pending in PiP',
    () => withClock(Clock.fixed(DateTime(2026, 11, 3, 12, 1)), () async {
      final started = DateTime(2026, 11, 3, 12);
      final wizardAt = started.add(const Duration(seconds: 10));
      final db = DatabaseImpl(NativeDatabase.memory());
      final notifications = FakeNotificationsController();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final windows = <List<bool>>[];
      var dismissals = 0;
      const channel = MethodChannel('pl.diabeatthis.app/calculator_handoff');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dismiss') dismissals++;
        if (call.method == 'update') {
          windows.add((call.arguments['completed'] as List).cast<bool>());
        }
        return null;
      });
      addTearDown(() async {
        container.dispose();
        await db.close();
        messenger.setMockMethodCallHandler(channel, null);
      });
      await seedAddOnMeal(db, started, status: 'eating-extra');
      final pending = MealAddOnBolusContext(
        originalStatus: 'eating-extra',
        eatingStartedAt: started,
        requestedAt: started,
        coveredCarbs: 0,
        statusCoveredCarbs: 0,
        reportedExtendedCarbs: 15,
        requestedCarbs: 30,
        requestedExtendedCarbs: 15,
        awaitingBolus: true,
        bolusConfirmed: false,
      );
      await (db.update(db.meal)..where((row) => row.id.equals(1))).write(
        MealCompanion(addOnBolusContext: Value(pending.encode())),
      );
      container.read(databaseProvider);
      final controller = container.read(
        mealCalculatorRequestControllerProvider,
      );
      await controller.register(
        const AapsBolusSuggestionNotificationEvent(
          mealId: 1,
          carbs: 30,
          extendedCarbs: 15,
          extendedCarbsDelayMinutes: 45,
          extendedCarbsDurationMinutes: 120,
        ),
        sessionId: 'pip-1',
        openedAt: started,
      );
      final submissions = [
        {
          'at': wizardAt.millisecondsSinceEpoch,
          'carbs': 30,
          'valid': true,
          'complete': true,
        },
      ];
      await controller.observe({'submissions': submissions});
      final accepted = pending.copyWith(
        awaitingBolus: false,
        bolusConfirmed: true,
        requestedCarbs: 0,
        acceptedWizardKeys: ['at:${wizardAt.millisecondsSinceEpoch}'],
      );
      await (db.update(db.meal)..where((row) => row.id.equals(1))).write(
        MealCompanion(
          status: const Value('summarized'),
          addOnBolusContext: Value(accepted.encode()),
        ),
      );
      await controller.refresh();
      expect(dismissals, 0);
      expect(windows.last, [true, false, false]);

      final extended = <String, dynamic>{
        'id': 'carbs-1',
        'at': wizardAt.add(const Duration(minutes: 45)).millisecondsSinceEpoch,
        'carbs': 15,
        'duration': 0,
        'valid': true,
      };
      await controller.observe({
        'submissions': submissions,
        'extendedCarb': extended,
      });
      expect(dismissals, 0);
      expect(windows.last, [true, false, false]);
      await controller.observe({
        'submissions': submissions,
        'extendedCarb': {
          ...extended,
          'id': 'extended-1',
          'duration': const Duration(hours: 2).inMilliseconds,
        },
      });
      expect(windows.last, [true, true, true]);
    }),
  );
}
