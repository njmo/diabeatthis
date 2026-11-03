import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';

class RecordingForegroundPlatform extends FlutterForegroundTaskPlatform {
  bool running = false;
  final calls = <String>[];
  int? startedServiceId;
  String? startedTitle;
  String? startedText;

  @override
  Future<NotificationPermission> checkNotificationPermission() async =>
      NotificationPermission.granted;
  @override
  Future<bool> get isRunningService async => running;
  @override
  Future<void> startService({
    required AndroidNotificationOptions androidNotificationOptions,
    required IOSNotificationOptions iosNotificationOptions,
    required ForegroundTaskOptions foregroundTaskOptions,
    int? serviceId,
    List<ForegroundServiceTypes>? serviceTypes,
    required String notificationTitle,
    required String notificationText,
    NotificationIcon? notificationIcon,
    List<NotificationButton>? notificationButtons,
    String? notificationInitialRoute,
    Function? callback,
  }) async {
    calls.add('start');
    running = true;
    startedServiceId = serviceId;
    startedTitle = notificationTitle;
    startedText = notificationText;
  }

  @override
  Future<void> restartService() async {
    calls.add('restart');
  }

  @override
  Future<void> stopService() async {
    calls.add('stop');
    running = false;
  }
}

/// Records notification callback messages and delivers them to a production
/// foreground event handler, replacing only the plugin transport boundary.
class ResponseForwardingForegroundPlatform extends RecordingForegroundPlatform {
  final messages = <Object>[];
  void Function(Object data)? onData;

  @override
  void sendDataToTask(Object data) {
    messages.add(data);
    onData?.call(data);
  }
}
