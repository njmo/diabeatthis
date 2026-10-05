import '../../../../core/domain/model/device_status.dart';

enum AapsCarbsRequestSignalType { unavailable, positive, withdrawn }

class AapsCarbsRequestSignal {
  final AapsCarbsRequestSignalType type;
  final DeviceStatus? status;

  const AapsCarbsRequestSignal._(this.type, this.status);

  const AapsCarbsRequestSignal.unavailable()
    : this._(AapsCarbsRequestSignalType.unavailable, null);

  const AapsCarbsRequestSignal.positive(DeviceStatus status)
    : this._(AapsCarbsRequestSignalType.positive, status);

  const AapsCarbsRequestSignal.withdrawn(DeviceStatus status)
    : this._(AapsCarbsRequestSignalType.withdrawn, status);
}
