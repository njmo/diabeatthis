import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/provider/shared_prefs_provider.dart';
import 'data_source_config.dart';

part 'data_source_config_provider.g.dart';

const dataSourceBgSourceKey = 'data-source-bg-source';
const dataSourceEventSourceKey = 'data-source-event-source';
const dataSourceHistorySourceKey = 'data-source-history-source';
const dataSourceMirrorToLocalKey = 'data-source-mirror-to-local';

@riverpod
Future<DataSourceConfig> dataSourceConfig(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);

  return DataSourceConfig(
    bgSource: BgSource.fromStorage(prefs.getString(dataSourceBgSourceKey)),
    eventSource: EventSource.fromStorage(
      prefs.getString(dataSourceEventSourceKey),
    ),
    historySource: HistorySource.fromStorage(
      prefs.getString(dataSourceHistorySourceKey),
    ),
    mirrorToLocal: prefs.getBool(dataSourceMirrorToLocalKey) ?? false,
  );
}

@riverpod
DataSourceConfigController dataSourceConfigController(Ref ref) {
  return DataSourceConfigController(ref);
}

class DataSourceConfigController {
  const DataSourceConfigController(this._ref);

  final Ref _ref;

  Future<void> save(DataSourceConfig config) async {
    final prefs = await _ref.read(sharedPrefsProvider.future);

    await Future.wait([
      prefs.setString(dataSourceBgSourceKey, config.bgSource.storageValue),
      prefs.setString(
        dataSourceEventSourceKey,
        config.eventSource.storageValue,
      ),
      prefs.setString(
        dataSourceHistorySourceKey,
        config.historySource.storageValue,
      ),
      prefs.setBool(dataSourceMirrorToLocalKey, config.mirrorToLocal),
    ]);

    _ref.invalidate(dataSourceConfigProvider);
  }
}
