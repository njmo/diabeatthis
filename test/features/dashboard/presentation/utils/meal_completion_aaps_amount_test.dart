import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  for (final consumed in [0, 10]) {
    testWidgets(
      'completed meal uses actual $consumed carbs instead of planned carbs',
      (tester) async {
        const meal = Meal(
          id: 1,
          name: 'Meal',
          status: 'eating-then-bolus',
          carbs: 50,
        );
        final launcher = RecordingCompletionAapsLauncher();
        final notifications = FakeNotificationsController();
        Future<void>? operation;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(
                (ref) =>
                    throw StateError('Must not fall back to planned totals'),
              ),
              getMealAdviceProvider(meal).overrideWith((ref) async => null),
              notificationsControllerUiProvider.overrideWithValue(
                notifications,
              ),
              aapsLauncherProvider.overrideWithValue(launcher),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () {
                      operation = openAapsAfterBolusStatusUpdateIfNeeded(
                        context: context,
                        ref: ref,
                        meal: meal,
                        status: 'waiting-for-bolus',
                        consumedCarbs: consumed,
                      );
                    },
                    child: const Text('Complete'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Complete'));
        await tester.pumpAndSettle();
        await operation;
        if (consumed == 0) {
          expect(launcher.opens, 0);
          expect(notifications.shownEvents, isEmpty);
        } else {
          expect(launcher.opens, 1);
          final event =
              notifications.shownEvents.single
                  as AapsBolusSuggestionNotificationEvent;
          expect(event.carbs, 10);
          expect(event.mealId, 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class RecordingCompletionAapsLauncher extends AapsLauncher {
  int opens = 0;

  @override
  Future<AapsLaunchResult> openAaps() async {
    opens++;
    return AapsLaunchResult.opened;
  }
}
