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
