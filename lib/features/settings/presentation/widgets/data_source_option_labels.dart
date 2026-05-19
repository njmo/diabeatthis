import '../../../../core/data_sources/config/data_source_config.dart';

extension BgSourceLabel on BgSource {
  String get label {
    return switch (this) {
      BgSource.cloud => 'Chmura (Nightscout)',
      BgSource.aaps => 'AAPS lokalnie',
      BgSource.xdrip => 'xDrip+ lokalnie',
    };
  }
}

extension TreatmentsSourceLabel on TreatmentsSource {
  String get label {
    return switch (this) {
      TreatmentsSource.cloud => 'Chmura (Nightscout)',
      TreatmentsSource.aaps => 'AAPS lokalnie',
    };
  }
}

extension PumpStatusSourceLabel on PumpStatusSource {
  String get label {
    return switch (this) {
      PumpStatusSource.cloud => 'Chmura (Nightscout)',
      PumpStatusSource.aaps => 'AAPS lokalnie',
    };
  }
}

extension HistorySourceLabel on HistorySource {
  String get label {
    return switch (this) {
      HistorySource.cloud => 'Chmura (Nightscout)',
      HistorySource.local => 'Lokalnie',
    };
  }
}
