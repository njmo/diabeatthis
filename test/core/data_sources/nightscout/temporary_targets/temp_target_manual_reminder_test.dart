import 'package:diabeatthis/common/events/data/notification/temp_target_response_event.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_delivery_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../foreground/utils/fake_runtime_harness.dart';

void main() {
  test(
    'the legacy approval from the phone logs reports that no target was uploaded',
    () async {
      var uploadServiceRead = false;
      final notifications = FakeNotificationsController();
      final container = ProviderContainer(
        overrides: [
          tempTargetServiceProvider.overrideWith((_) {
            uploadServiceRead = true;
            throw StateError('Manual reminders cannot authorize an upload');
          }),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(harness.dispose);
      final response = TempTargetResponseEvent.fromJson({
        'action': 'agree',
        'entityId': 6,
        'targetType': 'activity',
        'tempTargetString': 'Activity',
      });
      NotificationResponseEventHandler().handle(
        NotificationResponseEvent.tempTargetResponse(data: response),
        harness.runtimeContext,
      );
      await Future<void>.delayed(Duration.zero);
      expect(uploadServiceRead, isFalse);
      expect(harness.emittedEvents, contains(response));
      expect(
        notifications.shownEvents.single,
        isA<TempTargetDeliveryNotification>(),
      );
      expect(
        notifications.shownEvents.single.body,
        lang.notificationTempTargetManualConfirmed,
      );
    },
  );

  test(
    'opening or rejecting a manual reminder does not trigger an upload or a confirmation',
    () async {
      final notifications = FakeNotificationsController();
      var uploadServiceRead = false;
      final container = ProviderContainer(
        overrides: [
          tempTargetServiceProvider.overrideWith((_) {
            uploadServiceRead = true;
            throw StateError('Manual reminders cannot authorize an upload');
          }),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(harness.dispose);
      for (final action in ['empty', 'dismiss', 'skip']) {
        final response = TempTargetResponseEvent.fromJson({
          'action': action,
          'entityId': 6,
          'targetType': 'activity',
          'tempTargetString': 'Activity',
        });
        NotificationResponseEventHandler().handle(
          NotificationResponseEvent.tempTargetResponse(data: response),
          harness.runtimeContext,
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(uploadServiceRead, isFalse);
      expect(notifications.shownEvents, isEmpty);
      expect(harness.emittedEvents, hasLength(3));
    },
  );

  test(
    'manual reminders and upload consent have distinct localized titles and instructions',
    () {
      final manual = TempTargetNotificationEvent.activity(entityId: 6);
      final consent = TempTargetNotificationEvent(
        entityId: 6,
        targetType: 'activity',
        requestId: 'consent',
        target: 140,
        durationMinutes: 90,
      );
      expect(manual.title, lang.notificationTempTargetManualTitle);
      expect(manual.body, lang.notificationTempTargetManualActivity);
      expect(consent.title, lang.notificationTempTargetTitle);
      expect(consent.body, lang.notificationTempTargetConsent(140, 90));
      expect(manual.title, isNot(consent.title));
    },
  );
}
