import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/app/providers/app_lifecycle_state_provider.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_presenter_provider.dart';
import 'package:diabeatthis/core/notifications/controllers/local_notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/events/family_chat_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_action_type.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/handlers/notification_response_handler.dart';
import 'package:diabeatthis/core/notifications/in_app/in_app_notification_center.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_entry.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_store.dart';
import 'package:diabeatthis/core/notifications/mappers/android_notification_details_mapper.dart';
import 'package:diabeatthis/core/notifications/providers/local_notifications_controller_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _LocalController extends LocalNotificationsController {
  _LocalController() : super(FlutterLocalNotificationsPlugin());

  final shown = <NotificationEvent>[];
  final retries = <NotificationEvent>[];
  final cancelled = <(int, String?)>[];
  Future<void> Function()? beforeShow;
  Future<void> Function()? beforeRetry;

  @override
  Future<void> show(NotificationEvent event) async {
    await beforeShow?.call();
    shown.add(event);
  }

  @override
  Future<void> showRetry(NotificationEvent event) async {
    await beforeRetry?.call();
    retries.add(event);
  }

  @override
  Future<void> cancel(int id, {String? tag}) async => cancelled.add((id, tag));
}

class _FailingRemovalPreferences extends SharedPreferencesAsync {
  final fail = ValueNotifier(false);

  @override
  Future<void> remove(String key) {
    if (fail.value) throw StateError('inbox unavailable');
    return super.remove(key);
  }
}

class _PausedInboxRead extends NotificationInboxStore {
  final entered = Completer<void>();
  final proceed = Completer<void>();

  @override
  Future<NotificationInboxEntry?> get(int id) async {
    if (!entered.isCompleted) {
      entered.complete();
      await proceed.future;
    }
    return super.get(id);
  }
}

void main() {
  test(
    'request confirmation uses the local notification open-request action',
    () {
      const event = FamilyChatNotificationEvent(
        id: 7,
        tag: 'sent',
        title: 'Request added',
        body: '',
        payload: {'type': 'familyChat', 'messageId': 'request'},
        openRequest: true,
        transient: true,
      );
      final restored = FamilyChatNotificationEvent.fromJson(event.toJson());
      final actions = AndroidNotificationDetailsMapper().map(restored).actions!;
      expect(actions.single.id, 'family_chat_open_request');
      expect(actions.single.showsUserInterface, isTrue);
      expect(restored.payload['messageId'], 'request');
    },
  );

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

  test(
    'Android treatment notification shows dedicated actions without suggestion chips',
    () {
      final details = AndroidNotificationDetailsMapper().map(message);
      final actions = details.actions!;
      expect(actions.map((action) => action.id), [
        NotificationActionType.familyChatConsume.toDarwinString(),
        NotificationActionType.familyChatTreatmentUnavailable.toDarwinString(),
        NotificationActionType.familyChatTreatmentFeelsWell.toDarwinString(),
      ]);
      expect(actions.last.allowGeneratedReplies, isFalse);
      expect(actions.last.inputs, isEmpty);
    },
  );

  ProviderContainer createContainer({
    List<Override> overrides = const [],
    bool allowChat = true,
  }) => ProviderContainer.test(
    overrides: [
      localNotificationsControllerProvider.overrideWithValue(local),
      familyChatInboxVisibilityProvider.overrideWithValue(
        (entries) async => allowChat ? entries : [],
      ),
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
    'pausing during the inbox read sends the notification to Android',
    () async {
      final store = _PausedInboxRead();
      await store.put(
        NotificationInboxEntry.fromEvent(
          message,
          id: message.id,
          createdAt: clock.now(),
          inApp: true,
        ),
      );
      final container = createContainer(
        overrides: [notificationInboxStoreProvider.overrideWithValue(store)],
      );
      final center = container.read(inAppNotificationCenterProvider.notifier);
      final presenting = center.present(message);
      await store.entered.future;
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.paused);
      store.proceed.complete();
      await presenting;
      expect(local.shown, [message]);
      expect(container.read(inAppNotificationCenterProvider).current, isNull);
    },
  );

  for (final paused in [false, true]) {
    test('purged chat retries are dropped even while paused=$paused', () async {
      final container = createContainer();
      final store = container.read(notificationInboxStoreProvider);
      final createdAt = clock.now();
      await store.put(
        NotificationInboxEntry.fromEvent(
          message,
          id: message.id,
          createdAt: createdAt,
          inApp: true,
        ),
      );
      await store.purgeFamilyChat();
      if (paused) {
        container
            .read(appLifecycleProvider.notifier)
            .setState(AppLifecycleState.paused);
      }
      final center = container.read(inAppNotificationCenterProvider.notifier);
      await center.present(message, retryOf: createdAt.millisecondsSinceEpoch);
      expect(container.read(inAppNotificationCenterProvider).current, isNull);
      expect(local.shown, isEmpty);
      expect(local.retries, isEmpty);
    });
  }

  test(
    'retained chat data is not presented when authorization is denied',
    () async {
      final container = createContainer(allowChat: false);
      final store = container.read(notificationInboxStoreProvider);
      final createdAt = clock.now();
      await store.put(
        NotificationInboxEntry.fromEvent(
          message,
          id: message.id,
          createdAt: createdAt,
          inApp: true,
        ),
      );
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.paused);
      await container
          .read(inAppNotificationCenterProvider.notifier)
          .present(message, retryOf: createdAt.millisecondsSinceEpoch);
      expect(local.shown, isEmpty);
      expect(local.retries, isEmpty);
    },
  );

  test(
    'a retry handed over after a pause asks Android to alert again',
    () async {
      final container = createContainer();
      final store = container.read(notificationInboxStoreProvider);
      final createdAt = clock.now();
      await store.put(
        NotificationInboxEntry.fromEvent(
          message,
          id: message.id,
          createdAt: createdAt,
          inApp: true,
        ),
      );
      final center = container.read(inAppNotificationCenterProvider.notifier);
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.paused);
      await center.present(message, retryOf: createdAt.millisecondsSinceEpoch);
      expect(local.shown, isEmpty);
      expect(local.retries, [message]);
    },
  );

  test(
    'only a successful retry handoff advances the durable attempt',
    () async {
      final container = createContainer();
      final store = container.read(notificationInboxStoreProvider);
      final now = clock.now();
      final due = now.subtract(const Duration(seconds: 1));
      await store.put(
        NotificationInboxEntry.fromEvent(
          message,
          id: message.id,
          createdAt: due.subtract(const Duration(minutes: 5)),
          retryAt: due,
          retriesRemaining: 2,
        ),
      );
      final claimDeadline = now.add(const Duration(seconds: 30));
      final entry = (await store.get(message.id))!;
      expect(
        await store.advanceRetry(
          entry,
          nextDue: due,
          remaining: 2,
          inApp: false,
          resetRead: false,
          leaseUntil: claimDeadline,
        ),
        isTrue,
      );
      final center = container.read(inAppNotificationCenterProvider.notifier);
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.paused);
      Future<void> deliver() => center.present(
        message,
        retryOf: entry.createdAt.millisecondsSinceEpoch,
        retryClaim: claimDeadline.millisecondsSinceEpoch,
      );

      local.beforeRetry = () async => throw StateError('Android unavailable');
      await deliver();
      expect(local.retries, isEmpty);
      expect((await store.get(message.id))?.retriesRemaining, 2);

      local.beforeRetry = null;
      await deliver();
      expect(local.retries, [message]);
      expect((await store.get(message.id))?.retriesRemaining, 1);

      await deliver();
      expect(local.retries, [message]);
    },
  );

  test('a late UI message cannot present a superseded claim', () async {
    final container = createContainer();
    final store = container.read(notificationInboxStoreProvider);
    final now = clock.now();
    final due = now.subtract(const Duration(seconds: 1));
    final firstClaim = now.add(const Duration(seconds: 25));
    final latestClaim = now.add(const Duration(seconds: 30));
    await store.put(
      NotificationInboxEntry.fromEvent(
        message,
        id: message.id,
        createdAt: due.subtract(const Duration(minutes: 5)),
        retryAt: due,
        retriesRemaining: 2,
      ),
    );
    Future<void> claim(DateTime deadline) async {
      expect(
        await store.advanceRetry(
          (await store.get(message.id))!,
          nextDue: due,
          remaining: 2,
          inApp: false,
          resetRead: false,
          leaseUntil: deadline,
        ),
        isTrue,
      );
    }

    await claim(firstClaim);
    await claim(latestClaim);
    final entry = (await store.get(message.id))!;
    final center = container.read(inAppNotificationCenterProvider.notifier);
    container
        .read(appLifecycleProvider.notifier)
        .setState(AppLifecycleState.paused);

    await center.present(
      message,
      retryOf: entry.createdAt.millisecondsSinceEpoch,
      retryClaim: firstClaim.millisecondsSinceEpoch,
    );
    expect(local.retries, isEmpty);
    expect((await store.get(message.id))?.retriesRemaining, 2);

    await center.present(
      message,
      retryOf: entry.createdAt.millisecondsSinceEpoch,
      retryClaim: latestClaim.millisecondsSinceEpoch,
    );
    expect(local.retries, [message]);
    expect((await store.get(message.id))?.retriesRemaining, 1);
  });

  test(
    'a delayed Android post restores the newer notification generation',
    () async {
      final container = createContainer();
      final store = container.read(notificationInboxStoreProvider);
      final createdAt = clock.now().subtract(const Duration(seconds: 1));
      await store.put(
        NotificationInboxEntry.fromEvent(
          message,
          id: message.id,
          createdAt: createdAt,
          inApp: true,
        ),
      );
      final entered = Completer<void>();
      final finish = Completer<void>();
      local.beforeRetry = () async {
        entered.complete();
        await finish.future;
      };
      final center = container.read(inAppNotificationCenterProvider.notifier);
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.paused);
      final older = center.present(
        message,
        retryOf: createdAt.millisecondsSinceEpoch,
      );
      await entered.future;

      final replacement = FamilyChatNotificationEvent(
        id: message.id,
        tag: message.tag,
        title: 'Reply sent',
        body: 'New status',
        payload: message.payload,
        silent: true,
      );
      await store.put(
        NotificationInboxEntry.fromEvent(
          replacement,
          id: replacement.id,
          createdAt: clock.now(),
        ),
      );
      await local.show(replacement);
      finish.complete();
      await older;

      expect(local.retries, [message]);
      expect(local.cancelled, contains((message.id, message.tag)));
      expect(local.shown.map((event) => event.body), [
        'New status',
        'New status',
      ]);
    },
  );

  test(
    'resuming during an Android post restores the banner after cancellation',
    () async {
      final container = createContainer();
      final entered = Completer<void>();
      final finish = Completer<void>();
      local.beforeShow = () async {
        entered.complete();
        await finish.future;
      };
      await container.read(notificationsControllerUiProvider).show(message);
      final lifecycle = container.read(appLifecycleProvider.notifier);
      lifecycle.setState(AppLifecycleState.paused);
      await entered.future;

      lifecycle.setState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(inAppNotificationCenterProvider).current, isNull);
      expect(local.cancelled, isEmpty);

      finish.complete();
      await Future<void>.delayed(Duration.zero);
      expect(local.shown, [message]);
      expect(local.cancelled, contains((message.id, message.tag)));
      expect(
        container.read(inAppNotificationCenterProvider).current?.id,
        message.id,
      );
    },
  );

  test(
    'chat history purge removes private entries and deletes legacy copies',
    () async {
      final regular = SharedPreferencesAsync();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final private = _FailingRemovalPreferences();
      final store = NotificationInboxStore(
        preferences: regular,
        chatPreferences: private,
      );
      final db = FamilyChatDatabase(NativeDatabase.memory(), null, store);
      addTearDown(db.close);
      const scope = '["user","family","epoch"]';
      NotificationInboxEntry entry(
        int id,
        String uid,
        String scope,
        int generation,
      ) => NotificationInboxEntry.fromEvent(
        FamilyChatNotificationEvent(
          id: id,
          tag: 'chat-$id',
          title: 'Chat',
          body: 'Private message',
          payload: {
            'uid': uid,
            'scope': scope,
            'historyGeneration': generation,
          },
        ),
        id: id,
        createdAt: clock.now(),
      );

      final old = entry(1, 'user', scope, 0);
      final oldKey = '${NotificationInboxStore.keyPrefix}1';
      await regular.setString(oldKey, jsonEncode(old.toJson()));
      expect(await store.visible(), isEmpty);
      expect(await regular.getString(oldKey), isNull);

      expect(await store.put(old), isTrue);
      expect(await regular.getString(oldKey), isNull);
      expect(await private.getString(oldKey), isNotNull);
      await store.put(entry(2, 'user', scope, 1));
      await store.put(entry(3, 'other', '["other","family","epoch"]', 0));
      private.fail.value = true;
      await expectLater(
        db.beginHistoryClear(scope, 0, 'operation'),
        throwsStateError,
      );
      expect(await db.historyState(scope), isEmpty);
      private.fail.value = false;

      await db.beginHistoryClear(scope, 0, 'operation');
      expect(
        (await store.visible()).map((entry) => entry.id),
        unorderedEquals([2, 3]),
      );

      await db.clearAccount('user');
      expect((await store.visible()).map((entry) => entry.id), [3]);
    },
  );

  test(
    'durable inbox revisions reject restored content after account clear',
    () async {
      final db = FamilyChatDatabase(
        NativeDatabase.memory(),
        null,
        NotificationInboxStore(),
      );
      addTearDown(db.close);
      const scope = '["user","family","epoch"]';
      Future<NotificationInboxEntry> entry(
        int id, {
        int generation = 0,
      }) async => NotificationInboxEntry.fromEvent(
        FamilyChatNotificationEvent(
          id: id,
          tag: 'chat-$id',
          title: 'Chat',
          body: 'Private message',
          payload: {
            'uid': 'user',
            'scope': scope,
            'historyGeneration': generation,
            'inboxRevision': await db.notificationInboxRevision('user', scope),
          },
        ),
        id: id,
        createdAt: clock.now(),
      );

      final accessChanged = NotificationInboxStore.changes.first;
      expect(await db.activateChat('user', scope, 'initial'), isTrue);
      await accessChanged;
      final old = await entry(1);
      expect(await db.authorizedInbox('user', [old]), [old]);
      expect(await db.authorizedInbox('other', [old]), isEmpty);

      await db.beginHistoryClear(scope, 0, 'operation');
      final fresh = await entry(2, generation: 1);
      expect(await db.authorizedInbox('user', [old, fresh]), [fresh]);
      await db.clearAccount('user');
      await db.deactivateChat();
      expect(await db.activateChat('user', scope, 'reenabled'), isTrue);
      final current = await entry(3);
      expect(await db.authorizedInbox('user', [old, fresh, current]), [
        current,
      ]);
    },
  );

  test(
    'treatment decline resolves the original before showing a status with the same ID',
    () async {
      final store = NotificationInboxStore();
      final status = FamilyChatNotificationEvent(
        id: message.id,
        tag: message.tag,
        title: 'Sent',
        body: 'Reply sent',
        payload: const {},
        transient: true,
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
              NotificationActionType.familyChatTreatmentUnavailable
                  .toDarwinString(),
            );
            expect(input, isNull);
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
          (action) =>
              action.type ==
              NotificationActionType.familyChatTreatmentUnavailable,
        ),
      );

      final current = container.read(inAppNotificationCenterProvider).current;
      expect(current?.event, same(status));
      expect(current?.actions, isEmpty);
      final stored = await store.get(message.id);
      expect(stored?.active, isFalse);
      expect(stored?.title, message.title);
      expect(container.read(inAppNotificationCenterProvider).inbox, isEmpty);
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
