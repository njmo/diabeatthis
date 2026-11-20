import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_presenter_provider.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/family_chat_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_delivery_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/in_app/in_app_notification_center.dart';
import 'package:diabeatthis/core/notifications/in_app/widgets/in_app_notification_host.dart';
import 'package:diabeatthis/core/notifications/in_app/widgets/notification_inbox.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_entry.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_foreground_task/methods');
  late List<Object?> sentToTask;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    sentToTask = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'sendData') sentToTask.add(call.arguments);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        familyChatInboxVisibilityProvider.overrideWithValue(
          (entries) async => entries,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => InAppNotificationHost(child: child!),
          home: Scaffold(
            appBar: AppBar(actions: const [NotificationInboxButton()]),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    return container;
  }

  Future<void> record(EatNowNotificationEvent event, {bool inApp = false}) =>
      NotificationInboxStore().put(
        NotificationInboxEntry.fromEvent(
          event,
          id: const HashNotificationIdFactory().create(event.key),
          createdAt: clock.now(),
          inApp: inApp,
        ),
      );

  testWidgets('swiping left clears only the selected inbox notification', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final first = EatNowNotificationEvent(mealId: 7, minutes: 15);
    final second = EatNowNotificationEvent(mealId: 8, minutes: 10);
    const ids = HashNotificationIdFactory();
    final firstId = ids.create(first.key);
    final secondId = ids.create(second.key);
    await tester.runAsync(() async {
      await record(first);
      await record(second);
      await container.read(inAppNotificationCenterProvider.notifier).refresh();
    });
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NotificationInboxButton),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(ValueKey(firstId)), const Offset(-550, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey(firstId)), findsNothing);
    expect(find.byKey(ValueKey(secondId)), findsOneWidget);
    expect(container.read(inAppNotificationCenterProvider).unreadCount, 0);
    await tester.runAsync(() async {
      final store = NotificationInboxStore();
      expect(await store.get(firstId), isNull);
      expect(await store.get(secondId), isNotNull);
    });
  });

  testWidgets(
    'an actionable banner hides after five seconds and stays unread',
    (tester) async {
      final container = await pumpApp(tester);
      final event = EatNowNotificationEvent(mealId: 7, minutes: 15);
      final id = const HashNotificationIdFactory().create(event.key);
      await tester.runAsync(() async {
        await record(event, inApp: true);
        await container
            .read(inAppNotificationCenterProvider.notifier)
            .present(event);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4999));
      expect(container.read(inAppNotificationCenterProvider).current?.id, id);
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(inAppNotificationCenterProvider).current, isNull);
      await tester.runAsync(() async {
        final stored = await NotificationInboxStore().get(id);
        expect(stored?.active, isTrue);
        expect(stored?.read, isFalse);
      });
    },
  );

  testWidgets('chat reply opens and focuses the inline composer on demand', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final event = FamilyChatNotificationEvent(
      id: 42,
      tag: 'chat',
      title: 'Family chat',
      body: 'Question?',
      payload: const {},
      replyChoices: const ['Yes'],
      message: (
        recipientId: 'child',
        recipientName: 'Child',
        senderId: 'caregiver',
        senderName: 'Caregiver',
        conversationTitle: 'Family',
        groupConversation: false,
        sentAt: clock.now(),
      ),
    );
    await tester.runAsync(() async {
      await NotificationInboxStore().put(
        NotificationInboxEntry.fromEvent(
          event,
          id: event.id,
          createdAt: clock.now(),
          inApp: true,
        ),
      );
      await container
          .read(inAppNotificationCenterProvider.notifier)
          .present(event);
    });
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Yes'), findsOneWidget);

    await tester.tap(find.text('Napisz odpowiedź'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'Własna odpowiedź');
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Własna odpowiedź'), findsOneWidget);
  });

  testWidgets('banner shows the definition buttons and answers like the '
      'system notification', (tester) async {
    final container = await pumpApp(tester);
    final event = EatNowNotificationEvent(mealId: 7, minutes: 15);
    final id = const HashNotificationIdFactory().create(event.key);
    await tester.runAsync(() => record(event));

    await tester.runAsync(
      () => container
          .read(inAppNotificationCenterProvider.notifier)
          .present(event),
    );
    await tester.pumpAndSettle();

    expect(find.text(event.title), findsOneWidget);
    expect(find.text(event.body), findsOneWidget);
    expect(find.text('Jeszcze nie'), findsOneWidget);

    await tester.tap(find.text('Zaczynam jeść'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text(event.title), findsNothing);
    expect(sentToTask, hasLength(1));
    expect(jsonDecode(sentToTask.single! as String), {
      'external_event': 'notification_event',
      'data': {
        'notification_response_event': 'eat_now_response',
        'data': {'action': 'eating', 'mealId': 7},
      },
    });
    final stored = await tester.runAsync(
      () => NotificationInboxStore().get(id),
    );
    expect(stored!.active, isFalse);
  });

  testWidgets('closing a banner removes its inbox entry', (tester) async {
    final container = await pumpApp(tester);
    final event = EatNowNotificationEvent(mealId: 8, minutes: 10);
    await tester.runAsync(() async {
      await record(event);
      await container
          .read(inAppNotificationCenterProvider.notifier)
          .present(event);
    });
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text(event.title), findsNothing);
    expect(sentToTask, isEmpty);

    expect(container.read(inAppNotificationCenterProvider).inbox, isEmpty);
  });

  testWidgets('informational banners dismiss themselves', (tester) async {
    final container = await pumpApp(tester);
    const event = TempTargetDeliveryNotification(message: 'Target ustawiony');
    await tester.runAsync(
      () => container
          .read(inAppNotificationCenterProvider.notifier)
          .present(event),
    );
    await tester.pumpAndSettle();
    expect(find.text('Target ustawiony'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Target ustawiony'), findsNothing);
  });

  testWidgets('the bell counts notifications delivered in the background', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await tester.runAsync(() async {
      await record(EatNowNotificationEvent(mealId: 1, minutes: 5));
      await record(EatNowNotificationEvent(mealId: 2, minutes: 5));
      await container.read(inAppNotificationCenterProvider.notifier).refresh();
    });
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(NotificationInboxButton));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(container.read(inAppNotificationCenterProvider).unreadCount, 0);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      tester.view.physicalSize.height / tester.view.devicePixelRatio / 2,
    );
    expect(find.byType(ListView), findsOneWidget);
    await tester.tap(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(BottomSheet)),
        ).notificationInboxClear,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('empty inbox is a compact sheet with a clear message', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(
      find.descendant(
        of: find.byType(NotificationInboxButton),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
    final scaffold = tester.element(find.byType(Scaffold));
    showNotificationInbox(scaffold);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      tester.view.physicalSize.height / tester.view.devicePixelRatio / 5,
    );
    expect(find.text('Brak powiadomień'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('an in-app notification whose message never reached the UI is '
      'restored from the inbox', (tester) async {
    final container = await pumpApp(tester);
    final event = EatNowNotificationEvent(mealId: 3, minutes: 5);
    final systemEvent = EatNowNotificationEvent(mealId: 4, minutes: 5);
    await tester.runAsync(() async {
      await record(event, inApp: true);
      await record(systemEvent);
      await container.read(inAppNotificationCenterProvider.notifier).refresh();
    });
    await tester.pumpAndSettle();

    final banners = container.read(inAppNotificationCenterProvider).banners;
    expect(banners.map((banner) => banner.event.toJson()), [event.toJson()]);
    expect(find.text(event.title), findsOneWidget);
  });

  testWidgets('a system AAPS reminder surfaces as a banner on refresh', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    const reminder = FamilyChatNotificationEvent(
      id: 712,
      tag: 'recorded-treatment',
      title: 'Zapisano dosłodzenie',
      body: 'Wpisz zapisane węglowodany w AAPS.',
      payload: {FamilyChatNotificationEvent.reviewAapsPayloadKey: true},
      silent: true,
    );
    await tester.runAsync(() async {
      await NotificationInboxStore().put(
        NotificationInboxEntry.fromEvent(
          reminder,
          id: reminder.id,
          createdAt: clock.now(),
        ),
      );
      await container.read(inAppNotificationCenterProvider.notifier).refresh();
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));

    final banner = container.read(inAppNotificationCenterProvider).current;
    expect(banner?.id, reminder.id);
    expect(banner?.opensOnTap, isTrue);
    expect(find.text(reminder.title), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Wpisz gramy w AAPS'),
      findsOneWidget,
    );
  });

  testWidgets('a new notification is shown above an unanswered one', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final older = EatNowNotificationEvent(mealId: 5, minutes: 5);
    const newer = TempTargetDeliveryNotification(message: 'Nowy target');
    final center = container.read(inAppNotificationCenterProvider.notifier);
    await tester.runAsync(() async {
      await center.present(older);
      await center.present(newer);
    });
    await tester.pumpAndSettle();

    expect(find.text('Nowy target'), findsOneWidget);
    expect(find.text(older.title), findsNothing);
    expect(find.text('+1 kolejne'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text(older.title), findsOneWidget);
  });
}
