import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/helpers/data_source_config_storer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('dataSourceConfigProvider', () {
    test('reads defaults when preferences are empty', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(dataSourceConfigProvider.future),
        completion(const DataSourceConfig.defaults()),
      );
    });

    test('ignores legacy event source preference', () async {
      SharedPreferences.setMockInitialValues({
        'data-source-event-source': 'aaps',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(dataSourceConfigProvider.future),
        completion(const DataSourceConfig.defaults()),
      );
    });

    test('reads stored source config', () async {
      SharedPreferences.setMockInitialValues({
        dataSourceBgSourceKey: 'xdrip',
        dataSourceTreatmentsSourceKey: 'aaps',
        dataSourcePumpStatusSourceKey: 'aaps',
        dataSourceHistorySourceKey: 'local',
        dataSourceMirrorToLocalKey: true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(dataSourceConfigProvider.future),
        completion(
          const DataSourceConfig(
            bgSource: BgSource.xdrip,
            treatmentsSource: TreatmentsSource.aaps,
            pumpStatusSource: PumpStatusSource.aaps,
            historySource: HistorySource.local,
            mirrorToLocal: true,
          ),
        ),
      );
    });

    test('saves source config', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const config = DataSourceConfig(
        bgSource: BgSource.aaps,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.aaps,
        historySource: HistorySource.local,
        mirrorToLocal: true,
      );

      final prefs = await SharedPreferences.getInstance();
      final storer = DataSourceConfigStorer(prefs);
      await storer.save(config);

      expect(prefs.getString(dataSourceBgSourceKey), 'aaps');
      expect(prefs.getString(dataSourceTreatmentsSourceKey), 'aaps');
      expect(prefs.getString(dataSourcePumpStatusSourceKey), 'aaps');
      expect(prefs.getString(dataSourceHistorySourceKey), 'local');
      expect(prefs.getBool(dataSourceMirrorToLocalKey), isTrue);
      await expectLater(
        container.read(dataSourceConfigProvider.future),
        completion(config),
      );
    });
  });
}
