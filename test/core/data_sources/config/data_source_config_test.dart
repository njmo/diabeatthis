import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataSourceConfig', () {
    test('uses cloud sources by default', () {
      const config = DataSourceConfig.defaults();

      expect(config.bgSource, BgSource.cloud);
      expect(config.treatmentsSource, TreatmentsSource.cloud);
      expect(config.pumpStatusSource, PumpStatusSource.cloud);
      expect(config.historySource, HistorySource.cloud);
      expect(config.mirrorToLocal, isFalse);
    });

    test('parses known storage values', () {
      expect(BgSource.fromStorage('aaps'), BgSource.aaps);
      expect(BgSource.fromStorage('xdrip'), BgSource.xdrip);
      expect(TreatmentsSource.fromStorage('aaps'), TreatmentsSource.aaps);
      expect(PumpStatusSource.fromStorage('aaps'), PumpStatusSource.aaps);
      expect(HistorySource.fromStorage('local'), HistorySource.local);
    });

    test('falls back to cloud for missing or unknown values', () {
      expect(BgSource.fromStorage(null), BgSource.cloud);
      expect(BgSource.fromStorage('unknown'), BgSource.cloud);
      expect(TreatmentsSource.fromStorage(null), TreatmentsSource.cloud);
      expect(TreatmentsSource.fromStorage('xdrip'), TreatmentsSource.cloud);
      expect(PumpStatusSource.fromStorage(null), PumpStatusSource.cloud);
      expect(PumpStatusSource.fromStorage('xdrip'), PumpStatusSource.cloud);
      expect(HistorySource.fromStorage(null), HistorySource.cloud);
      expect(HistorySource.fromStorage('unknown'), HistorySource.cloud);
    });

    test('detects push-based glucose sources', () {
      expect(BgSource.cloud.isPushBased, isFalse);
      expect(BgSource.aaps.isPushBased, isTrue);
      expect(BgSource.xdrip.isPushBased, isTrue);
    });

    test('detects push-based pump status sources', () {
      expect(PumpStatusSource.cloud.isPushBased, isFalse);
      expect(PumpStatusSource.aaps.isPushBased, isTrue);
    });

    test('detects when any configured source uses Nightscout', () {
      const localOnly = DataSourceConfig(
        bgSource: BgSource.aaps,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.aaps,
        historySource: HistorySource.local,
        mirrorToLocal: false,
      );
      const cloudHistory = DataSourceConfig(
        bgSource: BgSource.aaps,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.aaps,
        historySource: HistorySource.cloud,
        mirrorToLocal: false,
      );

      expect(localOnly.usesCloud, isFalse);
      expect(cloudHistory.usesCloud, isTrue);
      expect(const DataSourceConfig.defaults().usesCloud, isTrue);
    });
  });
}
