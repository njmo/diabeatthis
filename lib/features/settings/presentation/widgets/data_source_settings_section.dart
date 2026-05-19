import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../app/providers/app_foreground_bridge_provider.dart';
import '../../../../app/providers/foreground_task_state_provider.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../core/data/provider/monitor_service_enabled_provider.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/aaps/providers/aaps_receiver_controller_provider.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/config/helpers/data_source_config_storer.dart';
import '../../../../core/data_sources/xdrip/providers/xdrip_receiver_controller_provider.dart';
import '../../../../core/logger/logger.dart';
import 'data_source_config_controls.dart';
import 'settings_section_card.dart';

class DataSourceSettingsSection extends ConsumerWidget with Logging {
  const DataSourceSettingsSection({super.key, this.onChanged});

  final ValueChanged<DataSourceConfig>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(dataSourceConfigProvider);

    return SettingsSectionCard(
      icon: Icons.hub_outlined,
      title: 'Źródła danych',
      subtitle: 'Wybierz źródło cukru, zdarzeń, statusu pompy i historii.',
      children: [
        configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Błąd źródeł danych: $error'),
          data: (config) => DataSourceConfigControls(
            config: config,
            onChanged: (next) async {
              final prefs = await ref.read(sharedPrefsProvider.future);
              final storer = DataSourceConfigStorer(prefs);
              final appEventRouter = ref.read(appEventRouterProvider);

              await storer.save(next);
              final xdripReceiverController = ref.read(
                xdripReceiverControllerProvider,
              );
              final wasXdrip = config.bgSource == BgSource.xdrip;
              final isXdrip = next.bgSource == BgSource.xdrip;
              if (isXdrip && !wasXdrip) {
                await xdripReceiverController.setEnabled();
              } else if (!isXdrip && wasXdrip) {
                await xdripReceiverController.setDisabled();
              }
              final aapsReceiverController = ref.read(
                aapsReceiverControllerProvider,
              );
              final wasAapsPumpStatus =
                  config.pumpStatusSource == PumpStatusSource.aaps;
              final isAapsPumpStatus =
                  next.pumpStatusSource == PumpStatusSource.aaps;
              if (isAapsPumpStatus && !wasAapsPumpStatus) {
                await aapsReceiverController.setEnabled();
              } else if (!isAapsPumpStatus && wasAapsPumpStatus) {
                await aapsReceiverController.setDisabled();
              }
              ref.invalidate(sharedPrefsProvider);
              await _restartForegroundTaskIfNeeded(ref, config, next);

              appEventRouter.send(
                ExecuteCommandEvent.syncSettings(data: next.toSyncPayload()),
              );
              onChanged?.call(next);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _restartForegroundTaskIfNeeded(
    WidgetRef ref,
    DataSourceConfig previous,
    DataSourceConfig next,
  ) async {
    if (!_foregroundSourcesChanged(previous, next)) return;
    if (!ref.read(monitorServiceEnabledProvider)) return;

    final foregroundBridge = ref.read(appForegroundBridgeProvider);
    final taskState = ref.read(foregroundTaskStateProvider.notifier);

    try {
      taskState.setAlive(false);
      final isRunning = await foregroundBridge.isServiceRunning();
      if (isRunning) {
        await foregroundBridge.restartService();
      } else {
        await foregroundBridge.startMonitoring();
      }
      await taskState.waitForStartupMessage();
    } catch (e, st) {
      logW('Foreground restart after data source change failed: $e\n$st');
    }
  }

  bool _foregroundSourcesChanged(
    DataSourceConfig previous,
    DataSourceConfig next,
  ) {
    return previous.bgSource != next.bgSource ||
        previous.eventSource != next.eventSource ||
        previous.pumpStatusSource != next.pumpStatusSource ||
        previous.historySource != next.historySource;
  }
}

extension _DataSourceConfigSyncPayload on DataSourceConfig {
  Map<String, String> toSyncPayload() {
    return {
      dataSourceBgSourceKey: bgSource.storageValue,
      dataSourceEventSourceKey: eventSource.storageValue,
      dataSourcePumpStatusSourceKey: pumpStatusSource.storageValue,
      dataSourceHistorySourceKey: historySource.storageValue,
      dataSourceMirrorToLocalKey: mirrorToLocal.toString(),
    };
  }
}
