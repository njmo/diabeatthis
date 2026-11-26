import 'package:diabeatthis/app/event/app/app_event_router.dart';
import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/common/events/data/app_event_data.dart';
import 'package:diabeatthis/common/meal_advisor/finish_meal_decision.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event_type.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_key.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/internal/meal_decision_finished.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/utils/fake_notifications_controller.dart';

class _RecordingRouter extends AppEventRouter {
  final sent = <AppEventData>[];

  @override
  void send(AppEventData payload) => sent.add(payload);
}

void main() {
  test(
    'finishing a decision clears the advisor offer and wakes the monitor',
    () async {
      final notifications = FakeNotificationsController();
      final router = _RecordingRouter();
      final container = ProviderContainer(
        overrides: [
          notificationsControllerUiProvider.overrideWithValue(notifications),
          appEventRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);

      await container.read(finishMealDecisionProvider)(7);

      expect(notifications.cancelledIds, [
        const HashNotificationIdFactory().create(
          const NotificationKey(
            type: NotificationEventType.plannedMealAdvice,
            entityId: 7,
          ),
        ),
      ]);
      expect(router.sent.single, isA<MealDecisionFinished>());
      expect((router.sent.single as MealDecisionFinished).mealId, 7);
    },
  );
}
