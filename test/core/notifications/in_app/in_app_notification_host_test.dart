import 'dart:convert';

import 'package:clock/clock.dart';
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
    final container = ProviderContainer();
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
    await tester.runAsync(
      () => container
          .read(inAppNotificationCenterProvider.notifier)
          .present(event),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Yes'), findsNothing);

    await tester.tap(find.text('Odpowiedz'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
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

  testWidgets('closing a banner keeps the notification answerable from the '
      'inbox', (tester) async {
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

    await tester.tap(find.byType(NotificationInboxButton));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text(event.title), findsOneWidget);
    expect(find.text('Zaczynam jeść'), findsOneWidget);
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
