import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../../../core/logger/logger.dart';
import '../../../features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import '../../../features/dashboard/data/providers/device_status_ui_provider.dart';
import '../../../features/dashboard/data/providers/temporary_target_ui_provider.dart';
import '../../../foreground/providers/blood_sugar_value_provider.dart';

class DataSynchronizationBridge with Logging {
  final WidgetRef _ref;

  DataSynchronizationBridge(this._ref);

  void handle(TaskDataSynchronizationPayload event) {
    logI("Received data synchronization event $event");
    event.when(
      glucose: (data) {
        logI("Received glucose event");
        _ref.read(bloodSugarValueProvider.notifier).update(data);
        _ref.read(bloodSugarReadingsListProvider.notifier).update(data);
      },
      deviceStatus: (data) {
        logI("Received device status event");
        _ref.read(deviceStatusUiProvider.notifier).update(data);
      },
      list: (List<TaskDataSynchronizationPayload> data) {
        logI("Received list event count=${data.length}");
        for (final d in data) {
          handle(d);
        }
      },
      target: (TemporaryTarget data) {
        logI("Received target event");
        _ref.read(temporaryTargetUiProvider.notifier).update(data);
      },
    );
  }
}
