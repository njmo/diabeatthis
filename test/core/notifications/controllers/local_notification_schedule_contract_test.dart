import 'dart:convert';

import 'package:diabeatthis/core/notifications/controllers/local_notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_summary_reminder_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platformChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const delay = Duration(minutes: 2);
  final calls = <MethodCall>[];
  final pendingRequests = <int, Map<String, Object?>>{};
  late LocalNotificationsController controller;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
    controller = LocalNotificationsController(
      FlutterLocalNotificationsPlugin(),
    );
    calls.clear();
    pendingRequests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'show':
              return null;
            case 'zonedSchedule':
              final arguments = Map<String, Object?>.from(
                call.arguments as Map,
              );
              final id = arguments['id']! as int;
              pendingRequests[id] = {
                'id': id,
                'title': arguments['title'],
                'body': arguments['body'],
                'payload': arguments['payload'],
              };
              return null;
            case 'cancel':
              pendingRequests.remove((call.arguments! as Map)['id']! as int);
              return null;
            case 'pendingNotificationRequests':
              return pendingRequests.values.toList();
            default:
              throw StateError('Unexpected platform call: ${call.method}');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'summary reminders reach native schedule with the intended time, zone, payload, and scoped identity',
    () async {
      final first = MealSummaryReminderNotificationEvent(mealId: 52);
      final second = MealSummaryReminderNotificationEvent(mealId: 53);

      final before = DateTime.now().toUtc();
      await controller.show(first);
      await controller.schedule(first, delay);
      final after = DateTime.now().toUtc();
      await controller.show(second);
      await controller.schedule(second, delay);

      final nativeCalls = calls.toList();
      final firstShow = _argumentsFor(nativeCalls, 'show', 0);
      final firstSchedule = _argumentsFor(nativeCalls, 'zonedSchedule', 0);
      final secondShow = _argumentsFor(nativeCalls, 'show', 1);
      final secondSchedule = _argumentsFor(nativeCalls, 'zonedSchedule', 1);

      final firstId = firstShow['id']! as int;
      final secondId = secondShow['id']! as int;
      expect(firstId, isNot(secondId));
      expect(firstSchedule['id'], firstId);
      expect(secondSchedule['id'], secondId);
      expect(firstId, const HashNotificationIdFactory().create(first.key));
      expect(secondId, const HashNotificationIdFactory().create(second.key));

      final scheduledInstant = DateTime.parse(
        firstSchedule['scheduledDateTimeISO8601']! as String,
      ).toUtc();
      expect(
        scheduledInstant.isBefore(before.add(delay)),
        isFalse,
        reason: 'Native schedule must not be earlier than the requested delay.',
      );
      expect(
        scheduledInstant.isAfter(after.add(delay)),
        isFalse,
        reason: 'Native schedule must remain within the call-time boundary.',
      );
      expect(firstSchedule['timeZoneName'], 'Europe/Warsaw');
      final localScheduled = tz.TZDateTime.from(scheduledInstant, tz.local);
      final wallTime = DateTime.parse(
        firstSchedule['scheduledDateTime']! as String,
      );
      expect(
        (
          wallTime.year,
          wallTime.month,
          wallTime.day,
          wallTime.hour,
          wallTime.minute,
        ),
        (
          localScheduled.year,
          localScheduled.month,
          localScheduled.day,
          localScheduled.hour,
          localScheduled.minute,
        ),
      );
      expect(
        (firstSchedule['platformSpecifics']! as Map)['scheduleMode'],
        AndroidScheduleMode.exactAllowWhileIdle.name,
      );

      _expectSummaryPayload(firstShow, first.mealId);
      _expectSummaryPayload(firstSchedule, first.mealId);
      _expectSummaryPayload(secondShow, second.mealId);
      _expectSummaryPayload(secondSchedule, second.mealId);

      expect(await controller.pending, {firstId, secondId});
      await controller.cancel(firstId);
      expect(calls.last.method, 'cancel');
      expect((calls.last.arguments as Map)['id'], firstId);
      expect(await controller.pending, {secondId});
    },
  );
}

Map<String, Object?> _argumentsFor(
  List<MethodCall> calls,
  String method,
  int index,
) {
  final call = calls.where((call) => call.method == method).elementAt(index);
  return Map<String, Object?>.from(call.arguments as Map);
}

void _expectSummaryPayload(Map<String, Object?> arguments, int mealId) {
  final payload = jsonDecode(arguments['payload']! as String) as Map;
  expect(payload['response_event_type'], 'meal_summary_reminder_response');
  expect((payload['action_data'] as Map)['mealId'], mealId);
}
