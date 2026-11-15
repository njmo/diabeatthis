import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/providers/app_event_router_provider.dart';
import '../../../app/providers/app_foreground_bridge_provider.dart';
import '../../../app/providers/foreground_task_state_provider.dart';
import '../../../common/app_mode/application_device_mode.dart';
import '../../../common/events/data/app/execute_command_event.dart';
import '../../../common/events/data/app/sync_data_key.dart';
import '../../../common/l10n/application_language.dart';
import '../../../common/l10n/application_language_storage_keys.dart';
import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/monitor_service_enabled_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../../core/data_sources/config/data_source_config.dart';
import '../../../core/data_sources/config/data_source_config_sync_payload.dart';
import '../../../core/data_sources/config/data_source_option_availability.dart';
import '../../../core/data_sources/config/helpers/data_source_config_storer.dart';
import '../../../core/data_sources/nightscout/nightscout_connection_verification.dart';
import '../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';
import '../../../core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import '../../../foreground/service/monitoring_startup_exception.dart';
import '../data/settings_storage_keys.dart';

part 'apply_initial_configuration_use_case.g.dart';

@riverpod
ApplyInitialConfigurationUseCase applyInitialConfigurationUseCase(Ref ref) {
  return ApplyInitialConfigurationUseCase(ref);
}

class ApplyInitialConfigurationUseCase {
  ApplyInitialConfigurationUseCase(this._ref, [this._beforeCompletion]);

  final Ref _ref;
  final Future<void> Function()? _beforeCompletion;

  Future<void> call({
    required DataSourceConfig config,
    required String nightscoutUrl,
    required String nightscoutToken,
    required String childName,
    required ApplicationLanguage language,
    bool tempTargetsEnabled = false,
    bool lowTreatmentsEnabled = false,
  }) async {
    final availability = await _ref.read(
      dataSourceOptionAvailabilityProvider.future,
    );
    availability.ensureConfigAvailable(config);

    if (config.usesCloud &&
        !_ref
            .read(nightscoutConnectionVerificationProvider)
            .matches(url: nightscoutUrl, token: nightscoutToken)) {
      await _ref.read(nightscoutConnectionCheckProvider)(
        url: nightscoutUrl,
        token: nightscoutToken,
      );
    }

    final prefs = await _ref.read(sharedPrefsProvider.future);
    final dataSourceConfigStorer = DataSourceConfigStorer(prefs);

    await dataSourceConfigStorer.save(config);
    if (!await prefs.setString(
      applicationDeviceModeKey,
      ApplicationDeviceMode.patient.name,
    )) {
      throw StateError('Patient mode was not saved.');
    }
    await Future.wait([
      if (config.usesCloud)
        prefs.setString(nightscoutUrlKey, nightscoutUrl.trim()),
      if (config.usesCloud)
        prefs.setString(nightscoutTokenKey, nightscoutToken.trim()),
      prefs.setBool(nightscoutTempTargetsEnabledKey, tempTargetsEnabled),
      prefs.setBool(nightscoutLowTreatmentsEnabledKey, lowTreatmentsEnabled),
      prefs.setString(childNameKey, childName.trim()),
      prefs.setString(applicationLanguageCodeKey, language.code),
    ]);
    setLanguageStringsFromCode(language.code);
    await _ref
        .read(dataReceiverActivationControllerProvider)
        .enableConfiguredReceivers(config);

    if (!_ref.mounted) return;

    _ref.invalidate(sharedPrefsProvider);

    try {
      await _startForegroundIfEnabled();
    } catch (error) {
      throw MonitoringStartupException(error);
    }
    if (!_ref.mounted) return;
    _sendStartupSync(config);
    await _beforeCompletion?.call();
    if (!await prefs.setBool(initialConfigurationDoneKey, true)) {
      throw StateError('Initial configuration completion was not saved.');
    }
    _ref.invalidate(initialConfigurationDoneProvider);
    _ref.invalidate(sharedPrefsProvider);
  }

  Future<void> _startForegroundIfEnabled() async {
    _ref.invalidate(applicationDeviceModeProvider);
    await _ref.read(applicationDeviceModeProvider.future);
    if (!_ref.mounted) return;
    final enabled = _ref.read(monitorServiceEnabledProvider);
    if (!enabled) return;

    final foregroundBridge = _ref.read(appForegroundBridgeProvider);
    final isServiceRunning = await foregroundBridge.isServiceRunning();
    final taskState = _ref.read(foregroundTaskStateProvider.notifier);
    taskState.setAlive(false);
    if (isServiceRunning) {
      await foregroundBridge.restartService();
    } else {
      await foregroundBridge.startMonitoring();
    }
    await taskState.waitForStartupMessage();
  }

  void _sendStartupSync(DataSourceConfig config) {
    final appEventRouter = _ref.read(appEventRouterProvider);
    appEventRouter.send(
      ExecuteCommandEvent.syncSettings(data: config.toSyncPayload()),
    );
    appEventRouter.send(
      const ExecuteCommandEvent.syncData(data: SyncDataKey.dashboardStartup),
    );
  }
}
