import '../config/data_source_config.dart';

enum DataReceiverSource {
  xdripGlucose,
  aaps;

  bool isActive(DataSourceConfig config) {
    return switch (this) {
      DataReceiverSource.xdripGlucose => config.bgSource == BgSource.xdrip,
      DataReceiverSource.aaps =>
        config.bgSource == BgSource.aaps ||
            config.treatmentsSource == TreatmentsSource.aaps ||
            config.pumpStatusSource == PumpStatusSource.aaps,
    };
  }
}
