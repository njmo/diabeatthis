import 'package:diabeatthis/foreground/service/foreground_service_controller.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/recording_foreground_platform.dart';

class FailingForegroundPlatform extends RecordingForegroundPlatform {
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
  }) async => throw StateError('Native foreground start rejected');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a plugin ServiceRequestFailure is propagated instead of waiting for alive',
    () async {
      final original = FlutterForegroundTaskPlatform.instance;
      final initialized = FlutterForegroundTask.isInitialized;
      final skip = FlutterForegroundTask.skipServiceResponseCheck;
      FlutterForegroundTaskPlatform.instance = FailingForegroundPlatform();
      FlutterForegroundTask.skipServiceResponseCheck = true;
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance = original;
        FlutterForegroundTask.isInitialized = initialized;
        FlutterForegroundTask.skipServiceResponseCheck = skip;
      });
      final controller = ForegroundServiceController();
      await controller.init();
      await expectLater(controller.startMonitoring(), throwsStateError);
    },
  );
}
