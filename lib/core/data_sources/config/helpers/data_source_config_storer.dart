import 'package:shared_preferences/shared_preferences.dart';

import '../data_source_config.dart';
import '../data_source_config_provider.dart';

class DataSourceConfigStorer {
  const DataSourceConfigStorer(this._prefs);

  final SharedPreferences _prefs;

  Future<void> save(DataSourceConfig config) async {
    await Future.wait([
      _prefs.setString(dataSourceBgSourceKey, config.bgSource.storageValue),
      _prefs.setString(
        dataSourceTreatmentsSourceKey,
        config.treatmentsSource.storageValue,
      ),
      _prefs.setString(
        dataSourcePumpStatusSourceKey,
        config.pumpStatusSource.storageValue,
      ),
      _prefs.setString(
        dataSourceHistorySourceKey,
        config.historySource.storageValue,
      ),
      _prefs.setBool(dataSourceMirrorToLocalKey, config.mirrorToLocal),
    ]);
  }
}
