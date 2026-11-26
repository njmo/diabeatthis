import 'package:clock/clock.dart';
import 'package:diabeatthis/app/providers/app_lifecycle_state_provider.dart';
import 'package:diabeatthis/core/notifications/controllers/notifications_controller_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/family_chat_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_identity.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_store.dart';
import 'package:diabeatthis/core/notifications/mappers/android_notification_details_mapper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  final local = FakeNotificationsController();
  final inApp = FakeNotificationsController();
  late DateTime now;
  late bool enabled, chatAuthorized;
  bool? chatRelevant;
  var verificationTime = Duration.zero;
  late ProviderContainer container;
  late NotificationsControllerImpl controller;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    local.shownEvents.clear();
    local.cancelledIds.clear();
    inApp.shownEvents.clear();
    now = DateTime(2026, 11, 19, 12);
    enabled = true;
    chatAuthorized = true;
    chatRelevant = true;
    verificationTime = Duration.zero;
    final provider = Provider(
      (ref) => NotificationsControllerImpl(
        ref,
        inApp,
        localController: local,
        inbox: NotificationInboxStore(),
        retriesEnabled: () async => enabled,
        retryStillRelevant: (event) async {
          now = now.add(verificationTime);
          return event is FamilyChatNotificationEvent ? chatRelevant : true;
        },
        withAuthorizedChatRetry: (_, _, deliver) async {
          if (chatAuthorized) await deliver();
        },
      ),
    );
    container = ProviderContainer();
    controller = container.read(provider);
  });
  tearDown(() => container.dispose());

  Future<void> advance(int minutes) async {
    now = now.add(Duration(minutes: minutes));
    await controller.processDueRetries();
  }

  // A separate store represents the response and push isolates.
  Future<void> answer(int id) => NotificationInboxStore().resolve(id);
  FamilyChatNotificationEvent parentMessage({
    int id = 42,
    List<String> replies = const [],
    int? timeoutAfter,
    bool lowTreatment = false,
  }) => FamilyChatNotificationEvent(
    id: id,
    tag: 'family:$id',
    title: 'Family',
    body: 'Are you ready?',
    payload: {
      'type': 'familyChat',
      if (lowTreatment)
        'authorization': const {
          'epoch': 'epoch',
          'accountOffGeneration': 0,
          'familyOffGeneration': 0,
        },
    },
    lowTreatment: lowTreatment,
    allowConsumption: lowTreatment,
    replyChoices: replies,
    timeoutAfter: timeoutAfter,
    message: (
      recipientId: 'child',
      recipientName: 'Child',
      senderId: 'parent',
      senderName: 'Parent',
      conversationTitle: 'Family',
      groupConversation: false,
      sentAt: now,
    ),
  );

  test(
    'a low-treatment request re-alerts Android three times at one-minute intervals',
    () async {
      await withClock(Clock(() => now), () async {
        final request = parentMessage(lowTreatment: true, timeoutAfter: 300000);
        await controller.show(request);
        expect(inApp.shownEvents, isEmpty);
        expect(local.shownEvents, hasLength(1));
        await NotificationInboxStore().markRead([request.id]);
        now = now.add(const Duration(seconds: 59));
        await advance(0);
        expect(local.shownEvents, hasLength(1));
        now = now.add(const Duration(seconds: 1));
        await advance(0);
        expect(local.shownEvents, hasLength(2));
        await advance(1);
        expect(local.shownEvents, hasLength(3));
        await advance(1);
        expect(local.shownEvents, hasLength(4));
        await advance(1);
        expect(local.shownEvents, hasLength(4));
        expect(local.shownEvents.map(notificationIdentity).toSet(), {
          notificationIdentity(request),
        });
      });
    },
  );

  test(
    'a failed treatment verification defers rather than consumes a retry',
    () async {
      await withClock(Clock(() => now), () async {
        final request = parentMessage(lowTreatment: true, timeoutAfter: 300000);
        await controller.show(request);
        chatRelevant = null;
        await advance(1);
        expect(local.shownEvents, hasLength(1));
        final entry = await NotificationInboxStore().get(request.id);
        expect(entry?.retriesRemaining, 3);
        expect(entry?.retryAt, now.add(const Duration(minutes: 1)));

        chatRelevant = true;
        await advance(0);
        expect(local.shownEvents, hasLength(1));
        await advance(1);
        expect(local.shownEvents, hasLength(2));
        expect(
          (await NotificationInboxStore().get(request.id))?.retriesRemaining,
          2,
        );
      });
    },
  );

  test(
    'failed verifications never re-check a request after its deadline',
    () async {
      await withClock(Clock(() => now), () async {
        final request = parentMessage(lowTreatment: true, timeoutAfter: 90000);
        await controller.show(request);
        chatRelevant = null;
        await advance(1);
        final deadline = DateTime(2026, 11, 19, 12, 1, 30);
        expect(
          (await NotificationInboxStore().get(request.id))?.retryAt,
          deadline,
        );

        now = deadline;
        await controller.processDueRetries();
        final retired = await NotificationInboxStore().get(request.id);
        expect(retired?.retriesRemaining, 0);
        chatRelevant = true;
        await advance(1);
        expect(local.shownEvents, hasLength(1));
      });
    },
  );

  test('a request that expires during verification is not posted', () async {
    await withClock(Clock(() => now), () async {
      final request = parentMessage(lowTreatment: true, timeoutAfter: 65000);
      await controller.show(request);
      verificationTime = const Duration(seconds: 10);
      await advance(1);
      expect(local.shownEvents, hasLength(1));
      expect(
        (await NotificationInboxStore().get(request.id))?.retriesRemaining,
        0,
      );
    });
  });

  test('answering a low-treatment request stops the next alert', () async {
    await withClock(Clock(() => now), () async {
      final request = parentMessage(lowTreatment: true, timeoutAfter: 300000);
      await controller.show(request);
      await advance(1);
      await answer(request.id);
      await advance(1);
      expect(local.shownEvents, hasLength(2));
    });
  });

  test('native chat retries request a new Android alert', () {
    final chat = parentMessage();
    expect(chat.toAndroidNotificationDetails().onlyAlertOnce, isTrue);
    expect(
      chat.toAndroidNotificationDetails(retry: true).onlyAlertOnce,
      isFalse,
    );
  });

  test(
    'a series rechecks app visibility and stops after two retries',
    () async {
      await withClock(Clock(() => now), () async {
        final event = FinishedEatingNotificationEvent(mealId: 1);
        final lifecycle = container.read(appLifecycleProvider.notifier);
        lifecycle.setState(AppLifecycleState.paused);
        await controller.show(event);
        expect(local.shownEvents, hasLength(1));
        await advance(4);
        expect(local.shownEvents, hasLength(1));

        lifecycle.setState(AppLifecycleState.resumed);
        await advance(1);
        expect(inApp.shownEvents, hasLength(1));
        lifecycle.setState(AppLifecycleState.paused);
        await advance(5);
        await advance(5);
        expect(local.shownEvents, hasLength(2));
        final entry = await NotificationInboxStore().get(
          notificationIdentity(event).id,
        );
        expect(entry?.retriesRemaining, 0);
      });
    },
  );

  test('plain chat stops on read and a question waits for an answer', () async {
    await withClock(Clock(() => now), () async {
      final plain = parentMessage();
      final question = parentMessage(id: 43, replies: ['Yes', 'No']);
      await controller.show(plain);
      await controller.show(question);
      await NotificationInboxStore().markRead([plain.id, question.id]);

      await advance(5);
      expect(inApp.shownEvents.map(notificationIdentity).map((id) => id.id), [
        plain.id,
        question.id,
        question.id,
      ]);
      await answer(question.id);
      await advance(5);
      expect(inApp.shownEvents, hasLength(3));
    });
  });

  test('disabling, cancelling, and losing chat access stop retries', () async {
    await withClock(Clock(() => now), () async {
      final disabled = FinishedEatingNotificationEvent(mealId: 7);
      await controller.show(disabled);
      enabled = false;
      await advance(5);
      enabled = true;
      await advance(5);
      expect(inApp.shownEvents, hasLength(1));

      final cancelled = FinishedEatingNotificationEvent(mealId: 8);
      final chat = parentMessage();
      final expired = parentMessage(id: 44, timeoutAfter: 120000);
      await controller.show(cancelled);
      await controller.show(chat);
      await controller.show(expired);
      chatAuthorized = false;
      await controller.cancel(notificationIdentity(cancelled).id);
      await advance(5);
      expect(inApp.shownEvents, hasLength(4));
    });
  });

  test(
    'a failed Android delivery leaves both durable retries available',
    () async {
      await withClock(Clock(() => now), () async {
        final meal = FinishedEatingNotificationEvent(mealId: 18);
        final id = notificationIdentity(meal).id;
        container
            .read(appLifecycleProvider.notifier)
            .setState(AppLifecycleState.paused);
        await controller.show(meal);
        local.enqueueShowError(StateError('temporary Android failure'));

        await advance(5);
        final inbox = NotificationInboxStore();
        expect((await inbox.get(id))?.retriesRemaining, 2);
        await advance(0);
        expect(local.shownEvents, hasLength(3));
        expect((await inbox.get(id))?.retriesRemaining, 1);
      });
    },
  );

  test(
    'unacknowledged UI retries recover through Android without losing a try',
    () async {
      await withClock(Clock(() => now), () async {
        final forwarded = <(int, int)>[];
        final provider = Provider(
          (ref) => NotificationsControllerImpl(
            ref,
            inApp,
            localController: local,
            retriesEnabled: () async => true,
            showInAppRetry: (_, original, due) async =>
                forwarded.add((original, due)),
          ),
        );
        final lifecycle = container.read(appLifecycleProvider.notifier);
        final routed = container.read(provider);
        final meal = FinishedEatingNotificationEvent(mealId: 19);
        final id = notificationIdentity(meal).id;
        await routed.show(meal);
        now = now.add(const Duration(minutes: 5));
        await routed.processDueRetries();
        expect(forwarded, hasLength(1));
        expect((await NotificationInboxStore().get(id))?.retriesRemaining, 2);

        lifecycle.setState(AppLifecycleState.paused);
        await routed.processDueRetries();
        expect(local.shownEvents, isEmpty);

        // Recreate the service-side owner with its original durable inbox state.
        final restarted = ProviderContainer();
        addTearDown(restarted.dispose);
        restarted
            .read(appLifecycleProvider.notifier)
            .setState(AppLifecycleState.paused);
        now = now.add(const Duration(seconds: 30));
        await restarted.read(provider).processDueRetries();
        expect(local.shownEvents, hasLength(1));
        expect((await NotificationInboxStore().get(id))?.retriesRemaining, 1);
      });
    },
  );

  test('scheduled alerts count from the scheduled time', () async {
    await withClock(Clock(() => now), () async {
      final meal = FinishedEatingNotificationEvent(mealId: 6);
      await controller.schedule(meal, const Duration(minutes: 8));
      await advance(12);
      expect(inApp.shownEvents, isEmpty);
      await advance(1);
      expect(inApp.shownEvents, hasLength(1));
      await answer(notificationIdentity(meal).id);
      await advance(5);
      expect(inApp.shownEvents, hasLength(1));
    });
  });
}
