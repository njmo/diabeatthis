import 'package:diabeatthis/common/notifications/android_notification_delivery.dart';
import 'package:diabeatthis/core/notifications/controllers/local_notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/mappers/android_notification_details_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platformChannel = MethodChannel('dexterous.com/flutter/notifications');
  const event = AapsBolusSuggestionNotificationEvent(
    mealId: 73,
    carbs: 0,
    extendedCarbs: 12,
    extendedCarbsDelayMinutes: 45,
    extendedCarbsDurationMinutes: 120,
  );
  final channelId = event.toAndroidNotificationDetails().channelId;
  final calls = <MethodCall>[];
  late LocalNotificationsController controller;
  late bool notificationsEnabled;
  late List<Map<String, Object?>> channels;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    controller = LocalNotificationsController(
      FlutterLocalNotificationsPlugin(),
    );
    notificationsEnabled = true;
    channels = [];
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'areNotificationsEnabled' => notificationsEnabled,
            'getNotificationChannels' => channels,
            'show' => null,
            _ => throw StateError('Unexpected platform call: ${call.method}'),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('disabled app rejects AAPS instructions before native show', () async {
    notificationsEnabled = false;

    await expectLater(
      controller.show(event),
      throwsA(
        isA<AndroidNotificationDeliveryException>()
            .having(
              (error) => error.reason,
              'reason',
              AndroidNotificationDeliveryBlock.applicationDisabled,
            )
            .having((error) => error.channelId, 'channelId', channelId),
      ),
    );
    expect(calls.map((call) => call.method), ['areNotificationsEnabled']);
  });

  test('disabled destination channel rejects AAPS instructions', () async {
    channels = [androidChannelResponse(channelId, Importance.none)];

    await expectLater(
      controller.show(event),
      throwsA(
        isA<AndroidNotificationDeliveryException>()
            .having(
              (error) => error.reason,
              'reason',
              AndroidNotificationDeliveryBlock.channelDisabled,
            )
            .having((error) => error.channelId, 'channelId', channelId),
      ),
    );
    expect(calls.map((call) => call.method), [
      'areNotificationsEnabled',
      'getNotificationChannels',
    ]);
  });

  test('absent channel allows first AAPS notification to create it', () async {
    await controller.show(event);

    expect(calls.map((call) => call.method), [
      'areNotificationsEnabled',
      'getNotificationChannels',
      'show',
    ]);
  });

  test(
    'enabled channel delivers the original extended carbs instruction',
    () async {
      channels = [androidChannelResponse(channelId, Importance.max)];

      await controller.show(event);

      expect(calls.map((call) => call.method), [
        'areNotificationsEnabled',
        'getNotificationChannels',
        'show',
      ]);
      final arguments = calls.last.arguments as Map;
      expect(arguments['title'], event.title);
      expect(arguments['platformSpecifics']['channelId'], channelId);
    },
  );

  test(
    'disabled unrelated channel does not suppress AAPS instructions',
    () async {
      channels = [androidChannelResponse('another_channel', Importance.none)];

      await controller.show(event);

      expect(calls.last.method, 'show');
    },
  );

  test(
    'other notification events retain their existing delivery path',
    () async {
      notificationsEnabled = false;

      await controller.show(FinishedEatingNotificationEvent(mealId: 73));

      expect(calls.map((call) => call.method), ['show']);
    },
  );
}

Map<String, Object?> androidChannelResponse(String id, Importance importance) =>
    {
      'id': id,
      'name': 'AAPS instructions',
      'importance': importance.value,
      'showBadge': true,
      'bypassDnd': false,
      'playSound': true,
      'enableLights': false,
      'enableVibration': true,
      'ledColor': 0,
      'audioAttributesUsage': AudioAttributesUsage.notification.value,
    };
