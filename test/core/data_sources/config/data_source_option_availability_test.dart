import 'package:diabeatthis/common/platform/external_app_installation_checker.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataSourceOptionAvailability', () {
    test('allows cloud sources without installed apps', () {
      const availability = DataSourceOptionAvailability.none();
      const config = DataSourceConfig.defaults();

      expect(availability.availableBgSources, [BgSource.cloud]);
      expect(availability.availableTreatmentsSources, [TreatmentsSource.cloud]);
      expect(availability.availablePumpStatusSources, [PumpStatusSource.cloud]);
      expect(availability.canUseBgSource(BgSource.cloud), isTrue);
      expect(
        availability.canUseTreatmentsSource(TreatmentsSource.cloud),
        isTrue,
      );
      expect(
        availability.canUsePumpStatusSource(PumpStatusSource.cloud),
        isTrue,
      );
      expect(availability.missingAppsFor(config), isEmpty);
    });

    test('marks AAPS missing once when any AAPS source is selected', () {
      const availability = DataSourceOptionAvailability(
        aapsInstalled: false,
        xdripInstalled: true,
      );
      const config = DataSourceConfig(
        bgSource: BgSource.aaps,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.aaps,
        historySource: HistorySource.local,
        mirrorToLocal: false,
      );

      expect(availability.missingAppsFor(config), {ExternalDataApp.aaps});
    });

    test('marks xDrip missing for xDrip glucose source', () {
      const availability = DataSourceOptionAvailability(
        aapsInstalled: true,
        xdripInstalled: false,
      );
      const config = DataSourceConfig(
        bgSource: BgSource.xdrip,
        treatmentsSource: TreatmentsSource.cloud,
        pumpStatusSource: PumpStatusSource.cloud,
        historySource: HistorySource.cloud,
        mirrorToLocal: false,
      );

      expect(availability.canUseBgSource(BgSource.xdrip), isFalse);
      expect(availability.missingAppsFor(config), {ExternalDataApp.xdrip});
    });

    test('keeps unavailable stored sources out of visible config', () {
      const availability = DataSourceOptionAvailability.none();
      const config = DataSourceConfig(
        bgSource: BgSource.xdrip,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.aaps,
        historySource: HistorySource.local,
        mirrorToLocal: true,
      );

      expect(
        availability.visibleConfigFor(config),
        const DataSourceConfig(
          bgSource: BgSource.cloud,
          treatmentsSource: TreatmentsSource.cloud,
          pumpStatusSource: PumpStatusSource.cloud,
          historySource: HistorySource.local,
          mirrorToLocal: true,
        ),
      );
    });
  });

  group('DataSourceOptionAvailability.ensureConfigAvailable', () {
    test('throws with missing apps before config can be saved', () async {
      const availability = DataSourceOptionAvailability.none();
      const config = DataSourceConfig(
        bgSource: BgSource.xdrip,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.cloud,
        historySource: HistorySource.local,
        mirrorToLocal: false,
      );

      expect(
        () => availability.ensureConfigAvailable(config),
        throwsA(
          isA<DataSourceConfigUnavailableException>().having(
            (error) => error.missingApps,
            'missingApps',
            {ExternalDataApp.aaps, ExternalDataApp.xdrip},
          ),
        ),
      );
    });

    test('allows config when selected local apps are installed', () async {
      const availability = DataSourceOptionAvailability(
        aapsInstalled: true,
        xdripInstalled: true,
      );
      const config = DataSourceConfig(
        bgSource: BgSource.xdrip,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.aaps,
        historySource: HistorySource.local,
        mirrorToLocal: true,
      );

      expect(() => availability.ensureConfigAvailable(config), returnsNormally);
    });
  });
}
