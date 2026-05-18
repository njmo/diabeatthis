import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
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
              ref.invalidate(sharedPrefsProvider);

              logI('Sending data source settings sync ${next.toSyncPayload()}');
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
