import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataSourceConfig', () {
    test('uses cloud sources by default', () {
      const config = DataSourceConfig.defaults();

      expect(config.bgSource, BgSource.cloud);
      expect(config.eventSource, EventSource.cloud);
      expect(config.pumpStatusSource, PumpStatusSource.cloud);
      expect(config.historySource, HistorySource.cloud);
      expect(config.mirrorToLocal, isFalse);
    });

    test('parses known storage values', () {
      expect(BgSource.fromStorage('aaps'), BgSource.aaps);
      expect(BgSource.fromStorage('xdrip'), BgSource.xdrip);
      expect(EventSource.fromStorage('aaps'), EventSource.aaps);
      expect(PumpStatusSource.fromStorage('aaps'), PumpStatusSource.aaps);
      expect(HistorySource.fromStorage('local'), HistorySource.local);
    });

    test('falls back to cloud for missing or unknown values', () {
      expect(BgSource.fromStorage(null), BgSource.cloud);
      expect(BgSource.fromStorage('unknown'), BgSource.cloud);
      expect(EventSource.fromStorage(null), EventSource.cloud);
      expect(EventSource.fromStorage('xdrip'), EventSource.cloud);
      expect(PumpStatusSource.fromStorage(null), PumpStatusSource.cloud);
      expect(PumpStatusSource.fromStorage('xdrip'), PumpStatusSource.cloud);
      expect(HistorySource.fromStorage(null), HistorySource.cloud);
      expect(HistorySource.fromStorage('unknown'), HistorySource.cloud);
    });
  });
}
