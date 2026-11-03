import 'package:diabeatthis/common/events/data/task/task_in_app_notification_payload.dart';
import 'package:diabeatthis/core/notifications/controllers/foreground_task_notification_controller.dart';
import 'package:diabeatthis/core/notifications/controllers/in_app_notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_carbs_request_notification.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/tasks/late_meal_completion_notification_test.dart'
    show CompletionRecordingTaskRouter;

void main() {
  test(
    'foreground notification retains event identity and amount across the bridge',
    () async {
      final router = CompletionRecordingTaskRouter();
      final provider = Provider(ForegroundTaskNotificationController.new);
      final container = ProviderContainer(
        overrides: [taskEventRouterProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);
      final controller = container.read(provider);
      await controller.init();
      const event = AapsCarbsRequestNotificationEvent(
        episodeId: 'episode-regression',
        carbs: 12.5,
      );
      await controller.show(event);
      expect(router.sent, hasLength(1));
      final payload = router.sent.single as TaskInAppNotificationPayload;
      expect(payload.type, event.type);
      expect(payload.data, {'episodeId': 'episode-regression', 'carbs': 12.5});
    },
  );
  test('in-app logging does not mutate notification payload', () async {
    final controller = InAppNotificationsController();
    const event = AapsCarbsRequestNotificationEvent(
      episodeId: 'local',
      carbs: 7.5,
    );
    await controller.init();
    await controller.show(event);
    expect(event.toJson(), {'episodeId': 'local', 'carbs': 7.5});
  });
}
