import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/app/providers/app_lifecycle_state_provider.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_presenter_provider.dart';
import 'package:diabeatthis/core/notifications/controllers/local_notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/events/family_chat_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_action_type.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/handlers/notification_response_handler.dart';
import 'package:diabeatthis/core/notifications/in_app/in_app_notification_center.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_store.dart';
import 'package:diabeatthis/core/notifications/providers/local_notifications_controller_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _LocalController extends LocalNotificationsController {
  _LocalController() : super(FlutterLocalNotificationsPlugin());

  final shown = <NotificationEvent>[];
  final cancelled = <(int, String?)>[];

  @override
  Future<void> show(NotificationEvent event) async => shown.add(event);

  @override
  Future<void> cancel(int id, {String? tag}) async => cancelled.add((id, tag));
}

void main() {
  final sentAt = DateTime(2026, 11, 19);
  final message = FamilyChatNotificationEvent(
    id: 42,
    tag: 'chat-tag',
    title: 'Ada',
    body: 'Lunch?',
    payload: const {'messageId': 'message-42'},
    message: (
      recipientId: 'recipient',
      recipientName: 'Jan',
      senderId: 'sender',
      senderName: 'Ada',
      conversationTitle: 'Family',
      groupConversation: true,
      sentAt: sentAt,
    ),
    allowConsumption: true,
    replyChoices: const ['Yes'],
    timeoutAfter: 60000,
  );

  late _LocalController local;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    local = _LocalController();
  });

  ProviderContainer createContainer({List<Override> overrides = const []}) =>
      ProviderContainer.test(
        overrides: [
          localNotificationsControllerProvider.overrideWithValue(local),
          ...overrides,
        ],
      );

  test('foreground delivery shows only a banner', () async {
    final container = createContainer();
    await container.read(notificationsControllerUiProvider).show(message);

    final state = container.read(inAppNotificationCenterProvider);
    expect(state.current?.event, same(message));
    expect(state.inbox.single.inApp, isTrue);
    expect(local.shown, isEmpty);
  });

  test(
    'a banner hands over to Android when the app leaves the foreground',
    () async {
      final container = createContainer();
      await container.read(notificationsControllerUiProvider).show(message);
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(inAppNotificationCenterProvider).current, isNull);
      expect(local.shown, [message]);

      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(inAppNotificationCenterProvider).current?.id,
        message.id,
      );
      expect(local.cancelled.last, (message.id, message.tag));
    },
  );

  test(
    'reply resolves the original before showing a status with the same ID',
    () async {
      final store = NotificationInboxStore();
      final status = FamilyChatNotificationEvent(
        id: message.id,
        tag: message.tag,
        title: 'Sent',
        body: 'Reply sent',
        payload: const {},
      );
      late ProviderContainer container;
      container = createContainer(
        overrides: [
          inAppNotificationResponderProvider.overrideWithValue(({
            required payload,
            required actionId,
            input,
            familyChatPresenter,
          }) async {
            expect(jsonDecode(payload), {
              ...message.payload,
              notificationIdPayloadKey: message.id,
            });
            expect(
              actionId,
              NotificationActionType.familyChatReply.toDarwinString(),
            );
            expect(input, 'Yes');
            expect(
              familyChatPresenter,
              same(container.read(familyChatUiPresenterProvider)),
            );
            expect((await store.get(message.id))?.active, isFalse);
            expect(local.cancelled.last, (message.id, message.tag));
            await container
                .read(notificationsControllerUiProvider)
                .show(status);
          }),
        ],
      );
      final center = container.read(inAppNotificationCenterProvider.notifier);
      await container.read(notificationsControllerUiProvider).show(message);
      final banner = container.read(inAppNotificationCenterProvider).current!;
      await center.respond(
        id: banner.id,
        event: banner.event,
        action: banner.actions.singleWhere(
          (action) => action.type == NotificationActionType.familyChatReply,
        ),
        input: 'Yes',
      );

      final current = container.read(inAppNotificationCenterProvider).current;
      expect(current?.event, same(status));
      expect(current?.actions, isEmpty);
      expect((await store.get(message.id))?.active, isTrue);
      expect(local.shown, isEmpty);
    },
  );

  test('a fresh center restores chat actions only before expiry', () async {
    await withClock(Clock.fixed(sentAt), () async {
      final original = createContainer();
      await original.read(notificationsControllerUiProvider).show(message);
      await Future<void>.delayed(Duration.zero);
      original.dispose();
    });

    for (final elapsed in [Duration.zero, const Duration(minutes: 1)]) {
      await withClock(Clock.fixed(sentAt.add(elapsed)), () async {
        final restarted = createContainer();
        await restarted
            .read(inAppNotificationCenterProvider.notifier)
            .refresh();
        await Future<void>.delayed(Duration.zero);
        final banner = restarted.read(inAppNotificationCenterProvider).current!;
        final restored = banner.event as FamilyChatNotificationEvent;
        expect((restored.id, restored.tag), (message.id, message.tag));
        expect(restored.payload, message.payload);
        expect(restored.body, message.body);
        expect(
          restored.message,
          elapsed == Duration.zero ? message.message : null,
        );
        expect(banner.actions.isNotEmpty, elapsed == Duration.zero);
        expect(
          banner.inputChoices,
          elapsed == Duration.zero ? ['Yes'] : isEmpty,
        );
        restarted.dispose();
      });
    }
  });

  test(
    'headless cancellation removes the banner in the UI container',
    () async {
      final ui = createContainer();
      final headless = createContainer();
      await ui.read(notificationsControllerUiProvider).show(message);
      expect(ui.read(inAppNotificationCenterProvider).current?.id, message.id);

      await headless
          .read(notificationsControllerHeadlessProvider)
          .cancel(message.id, tag: message.tag);
      await Future<void>.delayed(Duration.zero);

      expect(ui.read(inAppNotificationCenterProvider).current, isNull);
      expect(local.cancelled.last, (message.id, message.tag));
    },
  );
}
