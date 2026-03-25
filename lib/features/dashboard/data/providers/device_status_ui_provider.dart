import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/device_status.dart';

part 'device_status_ui_provider.g.dart';


@Riverpod(keepAlive: true)
class DeviceStatusUiNotifier extends _$DeviceStatusUiNotifier {
  @override
  DeviceStatus? build() {
    return null;
  }

  void update(DeviceStatus value) {
    state = value;
  }
}
