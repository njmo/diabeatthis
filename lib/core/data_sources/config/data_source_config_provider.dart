import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/provider/shared_prefs_provider.dart';
import 'data_source_config.dart';

part 'data_source_config_provider.g.dart';

const dataSourceBgSourceKey = 'data-source-bg-source';
const dataSourceEventSourceKey = 'data-source-event-source';
const dataSourcePumpStatusSourceKey = 'data-source-pump-status-source';
const dataSourceHistorySourceKey = 'data-source-history-source';
const dataSourceMirrorToLocalKey = 'data-source-mirror-to-local';

@Riverpod(keepAlive: true)
Future<DataSourceConfig> dataSourceConfig(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);

  return DataSourceConfig(
    bgSource: BgSource.fromStorage(prefs.getString(dataSourceBgSourceKey)),
    eventSource: EventSource.fromStorage(
      prefs.getString(dataSourceEventSourceKey),
    ),
    pumpStatusSource: PumpStatusSource.fromStorage(
      prefs.getString(dataSourcePumpStatusSourceKey),
    ),
    historySource: HistorySource.fromStorage(
      prefs.getString(dataSourceHistorySourceKey),
    ),
    mirrorToLocal: prefs.getBool(dataSourceMirrorToLocalKey) ?? false,
  );
}

@Riverpod(keepAlive: true)
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
        dataSourcePumpStatusSourceKey,
        config.pumpStatusSource.storageValue,
      ),
      prefs.setString(
        dataSourceHistorySourceKey,
        config.historySource.storageValue,
      ),
      prefs.setBool(dataSourceMirrorToLocalKey, config.mirrorToLocal),
    ]);

    if (!_ref.mounted) return;

    _ref.invalidate(dataSourceConfigProvider);
  }
}
