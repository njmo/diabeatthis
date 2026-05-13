import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import 'data_source_config_controls.dart';
import 'settings_section_card.dart';

class DataSourceSettingsSection extends ConsumerWidget {
  const DataSourceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(dataSourceConfigProvider);

    return SettingsSectionCard(
      icon: Icons.hub_outlined,
      title: 'Źródła danych',
      subtitle: 'Wybierz źródło cukru, zdarzeń i historii.',
      children: [
        configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Błąd źródeł danych: $error'),
          data: (config) => DataSourceConfigControls(
            config: config,
            onChanged: (next) async {
              final controller = ref.read(dataSourceConfigControllerProvider);
              final appEventRouter = ref.read(appEventRouterProvider);

              await controller.save(next);

              appEventRouter.send(
                const ExecuteCommandEvent.syncSettings(data: {}),
              );
            },
          ),
        ),
      ],
    );
  }
}
