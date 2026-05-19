import '../config/data_source_config.dart';

enum DataReceiverSource {
  xdripGlucose,
  aapsDeviceStatus;

  bool isActive(DataSourceConfig config) {
    return switch (this) {
      DataReceiverSource.xdripGlucose => config.bgSource == BgSource.xdrip,
      DataReceiverSource.aapsDeviceStatus =>
        config.pumpStatusSource == PumpStatusSource.aaps,
    };
  }
}
