import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
class ForegroundAlarmBridge {
  static const int collectAlarmId = 0xBABE;
  static const Duration _collectTickCoalesceWindow = Duration(seconds: 10);
  static final List<DateTime> _collectTickDeadlines = [];
  static DateTime? _scheduledCollectTickAt;

  static Future<void> scheduleCollectTick(DateTime at) async {
    _addCollectTickDeadline(at);
    await _scheduleNextCollectTick(clock.now());
  }

  static Future<void> markCollectTickDelivered(DateTime at) async {
    _collectTickDeadlines.removeWhere((deadline) => !deadline.isAfter(at));

    final scheduled = _scheduledCollectTickAt;
    if (scheduled != null && !scheduled.isAfter(at)) {
      _scheduledCollectTickAt = null;
    }

    await _scheduleNextCollectTick(at);
  }

  static Future<void> _scheduleNextCollectTick(DateTime now) async {
    _collectTickDeadlines.removeWhere((deadline) => deadline.isBefore(now));
    if (_collectTickDeadlines.isEmpty) return;

    final next = _collectTickDeadlines.reduce((a, b) => a.isBefore(b) ? a : b);

    final scheduled = _scheduledCollectTickAt;
    if (scheduled != null && scheduled.isAtSameMomentAs(next)) {
      return;
    }

    _scheduledCollectTickAt = next;
    await _scheduleCollectTickAt(next);
  }

  static void _addCollectTickDeadline(DateTime at) {
    final deadline = at.isBefore(clock.now()) ? clock.now() : at;

    final matchingIndex = _collectTickDeadlines.indexWhere(
      (current) =>
          current.difference(deadline).abs() <= _collectTickCoalesceWindow,
    );
    if (matchingIndex != -1) {
      final current = _collectTickDeadlines[matchingIndex];
      // Keep the later deadline so every merged waiter is ready when the tick fires.
      _collectTickDeadlines[matchingIndex] = deadline.isAfter(current)
          ? deadline
          : current;
      return;
    }

    _collectTickDeadlines.add(deadline);
  }

  static Future<void> _scheduleCollectTickAt(DateTime at) async {
    final now = clock.now();
    final deadline = at.isBefore(now) ? now : at;

    await AndroidAlarmManager.oneShotAt(
      deadline,
      collectAlarmId,
      _alarmEntryPoint,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: const <String, dynamic>{'reason': 'collect_tick'},
    );
  }

  static Future<void> cancelCollectTick() async {
    _collectTickDeadlines.clear();
    _scheduledCollectTickAt = null;
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
