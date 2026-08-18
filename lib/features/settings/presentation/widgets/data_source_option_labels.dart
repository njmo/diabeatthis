import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/config/data_source_config.dart';

extension BgSourceLabel on BgSource {
  String label(AppLocalizations lang) {
    return switch (this) {
      BgSource.cloud => lang.settingsDataSourceCloudNightscout,
      BgSource.aaps => lang.settingsDataSourceAapsLocal,
      BgSource.xdrip => lang.settingsDataSourceXdripLocal,
    };
  }
}

extension TreatmentsSourceLabel on TreatmentsSource {
  String label(AppLocalizations lang) {
    return switch (this) {
      TreatmentsSource.cloud => lang.settingsDataSourceCloudNightscout,
      TreatmentsSource.aaps => lang.settingsDataSourceAapsLocal,
    };
  }
}

extension PumpStatusSourceLabel on PumpStatusSource {
  String label(AppLocalizations lang) {
    return switch (this) {
      PumpStatusSource.cloud => lang.settingsDataSourceCloudNightscout,
      PumpStatusSource.aaps => lang.settingsDataSourceAapsLocal,
    };
  }
}

extension HistorySourceLabel on HistorySource {
  String label(AppLocalizations lang) {
    return switch (this) {
      HistorySource.cloud => lang.settingsDataSourceCloudNightscout,
      HistorySource.local => lang.settingsDataSourceLocal,
    };
  }
}
