import 'package:diabeatthis/foreground/service/foreground_service_controller.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/recording_foreground_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'monitor lifecycle delegates to the platform without duplicate service starts',
    () async {
      final original = FlutterForegroundTaskPlatform.instance;
      final initialized = FlutterForegroundTask.isInitialized;
      final skip = FlutterForegroundTask.skipServiceResponseCheck;
      final platform = RecordingForegroundPlatform();
      FlutterForegroundTaskPlatform.instance = platform;
      FlutterForegroundTask.skipServiceResponseCheck = true;
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance = original;
        FlutterForegroundTask.isInitialized = initialized;
        FlutterForegroundTask.skipServiceResponseCheck = skip;
      });
      final controller = ForegroundServiceController();
      await controller.init();
      expect(await controller.isRunning(), false);
      await controller.startMonitoring();
      expect(await controller.isRunning(), true);
      expect(platform.startedServiceId, 256);
      expect(platform.startedTitle, isNotEmpty);
      await controller.startMonitoring();
      expect(platform.calls, ['start']);
      await controller.restartMonitoring();
      await controller.stop();
      expect(platform.calls, ['start', 'restart', 'stop']);
      expect(await controller.isRunning(), false);
    },
  );
}
