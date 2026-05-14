import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
class ForegroundAlarmBridge {
  static const int collectAlarmId = 0x424242;

  static Future<void> scheduleCollectTick(DateTime at) async {
    await AndroidAlarmManager.oneShotAt(
      at,
      collectAlarmId,
      _alarmEntryPoint,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: const <String, dynamic>{'reason': 'collect_tick'},
    );
  }

  static Future<void> cancelCollectTick() async {
    await AndroidAlarmManager.cancel(collectAlarmId);
  }

  @pragma('vm:entry-point')
  static Future<void> _alarmEntryPoint(
    int id,
    Map<String, dynamic> params,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final payload = jsonEncode({
      'external_event': 'app_event',
      'data': {
        'app_event': 'execute_command',
        'data': {
          'command': 'collect_tick',
          'reason': params['reason'],
          'alarm_id': id,
        },
      },
    });

    FlutterForegroundTask.sendDataToTask(payload);
  }
}
