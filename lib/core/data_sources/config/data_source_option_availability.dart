import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/platform/external_app_installation_checker.dart';
import 'data_source_config.dart';

part 'data_source_option_availability.g.dart';

@riverpod
Future<DataSourceOptionAvailability> dataSourceOptionAvailability(
  Ref ref,
) async {
  final checker = ref.watch(externalAppInstallationCheckerProvider);
  final installedResults = await Future.wait([
    checker.isInstalled(ExternalDataApp.aaps),
    checker.isInstalled(ExternalDataApp.xdrip),
  ]);

  return DataSourceOptionAvailability(
    aapsInstalled: installedResults[0],
    xdripInstalled: installedResults[1],
  );
}

class DataSourceOptionAvailability {
  const DataSourceOptionAvailability({
    required this.aapsInstalled,
    required this.xdripInstalled,
  });

  const DataSourceOptionAvailability.none()
    : aapsInstalled = false,
      xdripInstalled = false;

  final bool aapsInstalled;
  final bool xdripInstalled;

  List<BgSource> get availableBgSources {
    return BgSource.values.where(canUseBgSource).toList();
  }

  List<TreatmentsSource> get availableTreatmentsSources {
    return TreatmentsSource.values.where(canUseTreatmentsSource).toList();
  }

  List<PumpStatusSource> get availablePumpStatusSources {
    return PumpStatusSource.values.where(canUsePumpStatusSource).toList();
  }

  bool canUseBgSource(BgSource source) {
    return switch (source) {
      BgSource.cloud => true,
      BgSource.aaps => aapsInstalled,
      BgSource.xdrip => xdripInstalled,
    };
  }

  bool canUseTreatmentsSource(TreatmentsSource source) {
    return switch (source) {
      TreatmentsSource.cloud => true,
      TreatmentsSource.aaps => aapsInstalled,
    };
  }

  bool canUsePumpStatusSource(PumpStatusSource source) {
    return switch (source) {
      PumpStatusSource.cloud => true,
      PumpStatusSource.aaps => aapsInstalled,
    };
  }

  Set<ExternalDataApp> missingAppsFor(DataSourceConfig config) {
    return {
      if (!_canUseAaps(config)) ExternalDataApp.aaps,
      if (config.bgSource == BgSource.xdrip && !xdripInstalled)
        ExternalDataApp.xdrip,
    };
  }

  void ensureConfigAvailable(DataSourceConfig config) {
    final missingApps = missingAppsFor(config);
    if (missingApps.isEmpty) return;

    throw DataSourceConfigUnavailableException(missingApps);
  }

  DataSourceConfig visibleConfigFor(DataSourceConfig config) {
    return config.copyWith(
      bgSource: canUseBgSource(config.bgSource)
          ? config.bgSource
          : BgSource.cloud,
      treatmentsSource: canUseTreatmentsSource(config.treatmentsSource)
          ? config.treatmentsSource
          : TreatmentsSource.cloud,
      pumpStatusSource: canUsePumpStatusSource(config.pumpStatusSource)
          ? config.pumpStatusSource
          : PumpStatusSource.cloud,
    );
  }

  bool _canUseAaps(DataSourceConfig config) {
    final usesAaps =
        config.bgSource == BgSource.aaps ||
        config.treatmentsSource == TreatmentsSource.aaps ||
        config.pumpStatusSource == PumpStatusSource.aaps;

    return !usesAaps || aapsInstalled;
  }
}

class DataSourceConfigUnavailableException implements Exception {
  const DataSourceConfigUnavailableException(this.missingApps);

  final Set<ExternalDataApp> missingApps;
}
