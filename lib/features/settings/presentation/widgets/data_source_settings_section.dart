import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            onChanged: (next) {
              ref.read(dataSourceConfigControllerProvider).save(next);
            },
          ),
        ),
      ],
    );
  }
}
