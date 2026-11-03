import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/monitoring/live_reading_order.dart';
import '../../../../core/domain/model/device_status.dart';

part 'device_status_ui_provider.g.dart';

@Riverpod(keepAlive: true)
class DeviceStatusUiNotifier extends _$DeviceStatusUiNotifier {
  @override
  DeviceStatus? build() {
    return null;
  }

  void update(DeviceStatus value) {
    final current = state;
    if (!acceptsLiveReading(
      incomingAt: value.date,
      incomingSource: value.source,
      currentAt: current?.date,
      currentSource: current?.source,
    )) {
      return;
    }
    state = value;
  }

  bool isUpdateNeeded() {
    final last = state;
    if (last == null) {
      return true;
    }
    return last.date.isBefore(clock.now().subtract(const Duration(minutes: 5)));
  }
}
