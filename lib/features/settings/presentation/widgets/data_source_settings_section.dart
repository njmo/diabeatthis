import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../app/providers/app_foreground_bridge_provider.dart';
import '../../../../app/providers/foreground_task_state_provider.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/platform/external_app_installation_checker.dart';
import '../../../../core/data/provider/monitor_service_enabled_provider.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import '../../../../core/data_sources/config/helpers/data_source_config_storer.dart';
import '../../../../core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import '../../../../core/logger/logger.dart';
import 'data_source_config_controls.dart';
import 'settings_section_card.dart';

class DataSourceSettingsSection extends ConsumerWidget with Logging {
  const DataSourceSettingsSection({super.key, this.onChanged});

  final ValueChanged<DataSourceConfig>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(dataSourceConfigProvider);
    final availabilityAsync = ref.watch(dataSourceOptionAvailabilityProvider);

    return SettingsSectionCard(
      icon: Icons.hub_outlined,
      title: context.lang.settingsDataSourcesTitle,
      subtitle: context.lang.settingsDataSourcesSubtitle,
      children: [
        configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Text(context.lang.settingsDataSourcesError(error)),
          data: (config) => availabilityAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Text(context.lang.settingsDataSourcesAvailabilityError(error)),
            data: (availability) => DataSourceConfigControls(
              config: config,
              availability: availability,
              onChanged: (next) async {
                if (next == config) return;

                try {
                  final availability = await ref.read(
                    dataSourceOptionAvailabilityProvider.future,
                  );
                  availability.ensureConfigAvailable(next);
                } on DataSourceConfigUnavailableException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_unavailableSourceMessage(context, e)),
                      ),
                    );
                  }
                  return;
                }

                final prefs = await ref.read(sharedPrefsProvider.future);
                final storer = DataSourceConfigStorer(prefs);
                final appEventRouter = ref.read(appEventRouterProvider);
                final receiverActivationController = ref.read(
                  dataReceiverActivationControllerProvider,
                );

                await storer.save(next);
                await receiverActivationController.applyConfigChange(
                  previous: config,
                  next: next,
                );
                ref.invalidate(sharedPrefsProvider);
                await _restartForegroundTaskIfNeeded(ref, config, next);

                appEventRouter.send(
                  ExecuteCommandEvent.syncSettings(data: next.toSyncPayload()),
                );
                onChanged?.call(next);
              },
            ),
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
        previous.treatmentsSource != next.treatmentsSource ||
        previous.pumpStatusSource != next.pumpStatusSource ||
        previous.historySource != next.historySource;
  }

  String _unavailableSourceMessage(
    BuildContext context,
    DataSourceConfigUnavailableException error,
  ) {
    final appNames = error.missingApps.map(_externalDataAppName).join(', ');
    return context.lang.settingsDataSourceUnavailable(appNames);
  }

  String _externalDataAppName(ExternalDataApp app) {
    return switch (app) {
      ExternalDataApp.aaps => 'AAPS',
      ExternalDataApp.xdrip => 'xDrip+',
    };
  }
}

extension _DataSourceConfigSyncPayload on DataSourceConfig {
  Map<String, String> toSyncPayload() {
    return {
      dataSourceBgSourceKey: bgSource.storageValue,
      dataSourceTreatmentsSourceKey: treatmentsSource.storageValue,
      dataSourcePumpStatusSourceKey: pumpStatusSource.storageValue,
      dataSourceHistorySourceKey: historySource.storageValue,
      dataSourceMirrorToLocalKey: mirrorToLocal.toString(),
    };
  }
}
