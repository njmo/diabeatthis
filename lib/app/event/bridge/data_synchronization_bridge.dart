import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../core/logger/logger.dart';
import '../../../features/dashboard/data/providers/device_status_ui_provider.dart';
import '../../../foreground/providers/blood_sugar_value_provider.dart';

class DataSynchronizationBridge with Logging {
  final WidgetRef _ref;

  DataSynchronizationBridge(this._ref);

  void handle(TaskDataSynchronizationPayload event) {
    event.when(
      glucose: (data) {
        logI("Received glucose event");
        _ref.read(bloodSugarValueProvider.notifier).update(data);
      },
      deviceStatus: (data) {
        logI("Received device status event");
        _ref.read(deviceStatusUiProvider.notifier).update(data);
        _ref.invalidate(glucoseWithLimitProvider);
      },
    );
  }
}
