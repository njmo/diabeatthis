import 'package:share_plus/share_plus.dart';

import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../../core/logger/logger.dart';
import '../../../providers/blood_sugar_value_provider.dart';
import '../../../providers/device_status_value_provider.dart';
import '../../../providers/task_event_router_provider.dart';
import '../../../task/base/runtime_context.dart';
import 'app_event.dart';

class AppEventHandler with Logging {
  AppEventHandler();

  void handle(AppEvent event, RuntimeContext runtimeContext) {
    event.when(
      appLifecycleState: (final data) {
        runtimeContext.emitEvent(data);
      },
      dumpLogs: (final data) async {
        final file = await LogFileWriter.writeLogs(Log.bufferedLogs, data.name);
        SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      },
      executeCommand: (final command) {
        logI("Received execute command event");
        command.when(syncData: (final data) {
          logI("Received sync data command");
          final router = runtimeContext.container.read(taskEventRouterProvider);
          final glucose = runtimeContext.container.read(bloodSugarValueProvider);
          logI("Sending glucose data $glucose");
          if (glucose != null) {
            final payload = TaskGlucoseSynchronization(data: glucose);
            router.send(payload);
          }
          final deviceStatus = runtimeContext.container.read(deviceStatusValueProvider);
          logI("Sending device status data $deviceStatus");
          if (deviceStatus != null) {
            final payload = TaskDeviceStatusSynchronization(data: deviceStatus);
            router.send(payload);
          }
        });
      },
    );
  }
}
