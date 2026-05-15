import 'data_source_config.dart';
import 'data_source_config_provider.dart';

extension DataSourceConfigSyncPayload on DataSourceConfig {
  Map<String, String> toSyncPayload() {
    return {
      dataSourceBgSourceKey: bgSource.storageValue,
      dataSourceEventSourceKey: eventSource.storageValue,
      dataSourcePumpStatusSourceKey: pumpStatusSource.storageValue,
      dataSourceHistorySourceKey: historySource.storageValue,
      dataSourceMirrorToLocalKey: mirrorToLocal.toString(),
    };
  }
}
