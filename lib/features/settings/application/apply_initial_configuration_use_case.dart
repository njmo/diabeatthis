import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/providers/app_event_router_provider.dart';
import '../../../app/providers/app_foreground_bridge_provider.dart';
import '../../../app/providers/foreground_task_state_provider.dart';
import '../../../common/events/data/app/execute_command_event.dart';
import '../../../common/events/data/app/sync_data_key.dart';
import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/monitor_service_enabled_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../../core/data_sources/aaps/providers/aaps_receiver_controller_provider.dart';
import '../../../core/data_sources/config/data_source_config.dart';
import '../../../core/data_sources/config/data_source_config_sync_payload.dart';
import '../../../core/data_sources/config/helpers/data_source_config_storer.dart';
import '../../../core/data_sources/nightscout/nightscout_cloud_connection_tester.dart';
import '../../../core/data_sources/xdrip/providers/xdrip_receiver_controller_provider.dart';
import '../data/settings_storage_keys.dart';

part 'apply_initial_configuration_use_case.g.dart';

@riverpod
ApplyInitialConfigurationUseCase applyInitialConfigurationUseCase(Ref ref) {
  return ApplyInitialConfigurationUseCase(ref);
}

class ApplyInitialConfigurationUseCase {
  ApplyInitialConfigurationUseCase(this._ref);

  final Ref _ref;

  Future<void> call({
    required DataSourceConfig config,
    required String nightscoutUrl,
    required String childName,
  }) async {
    if (config.usesCloud) {
      await NightscoutCloudConnectionTester.fromUrl(
        nightscoutUrl,
      ).testConnection();
    }

    final prefs = await _ref.read(sharedPrefsProvider.future);
    final dataSourceConfigStorer = DataSourceConfigStorer(prefs);

    await dataSourceConfigStorer.save(config);
    await Future.wait([
      if (config.usesCloud)
        prefs.setString(nightscoutUrlKey, nightscoutUrl.trim()),
      prefs.setString(childNameKey, childName.trim()),
      prefs.setBool(initialConfigurationDoneKey, true),
    ]);
    final xdripReceiverController = _ref.read(xdripReceiverControllerProvider);
    if (config.bgSource == BgSource.xdrip) {
      await xdripReceiverController.setEnabled();
    }
    final aapsReceiverController = _ref.read(aapsReceiverControllerProvider);
    if (config.pumpStatusSource == PumpStatusSource.aaps) {
      await aapsReceiverController.setEnabled();
    }

    if (!_ref.mounted) return;

    _ref.invalidate(sharedPrefsProvider);

    await _startForegroundIfEnabled();
    _sendStartupSync(config);
  }

  Future<void> _startForegroundIfEnabled() async {
    final enabled = _ref.read(monitorServiceEnabledProvider);
    if (!enabled) return;

    final foregroundBridge = _ref.read(appForegroundBridgeProvider);
    final isServiceRunning = await foregroundBridge.isServiceRunning();
    if (isServiceRunning) {
      throw StateError(
        'Foreground service is already running before initial configuration',
      );
    }

    final taskState = _ref.read(foregroundTaskStateProvider.notifier);
    await foregroundBridge.startMonitoring();
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
