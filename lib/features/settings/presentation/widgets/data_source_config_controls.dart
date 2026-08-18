import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import 'data_source_dropdown.dart';
import 'data_source_mirror_switch.dart';
import 'data_source_option_labels.dart';

class DataSourceConfigControls extends StatelessWidget {
  const DataSourceConfigControls({
    super.key,
    required this.config,
    required this.onChanged,
    required this.availability,
  });

  final DataSourceConfig config;
  final ValueChanged<DataSourceConfig> onChanged;
  final DataSourceOptionAvailability availability;

  @override
  Widget build(BuildContext context) {
    final visibleConfig = availability.visibleConfigFor(config);
    final bgDropdown = DataSourceDropdown<BgSource>(
      label: context.lang.settingsDataSourceBgLabel,
      value: visibleConfig.bgSource,
      values: availability.availableBgSources,
      labelFor: (source) => source.label(context.lang),
      onChanged: (source) =>
          onChanged(visibleConfig.copyWith(bgSource: source)),
    );
    final treatmentsDropdown = DataSourceDropdown<TreatmentsSource>(
      label: context.lang.settingsDataSourceTreatmentsLabel,
      value: visibleConfig.treatmentsSource,
      values: availability.availableTreatmentsSources,
      labelFor: (source) => source.label(context.lang),
      onChanged: (source) =>
          onChanged(visibleConfig.copyWith(treatmentsSource: source)),
    );
    final pumpStatusDropdown = DataSourceDropdown<PumpStatusSource>(
      label: context.lang.settingsDataSourcePumpStatusLabel,
      value: visibleConfig.pumpStatusSource,
      values: availability.availablePumpStatusSources,
      labelFor: (source) => source.label(context.lang),
      onChanged: (source) =>
          onChanged(visibleConfig.copyWith(pumpStatusSource: source)),
    );
    final historyDropdown = DataSourceDropdown<HistorySource>(
      label: context.lang.settingsDataSourceHistoryLabel,
      value: visibleConfig.historySource,
      values: HistorySource.values,
      labelFor: (source) => source.label(context.lang),
      onChanged: (source) =>
          onChanged(visibleConfig.copyWith(historySource: source)),
    );
    final mirrorSwitch = DataSourceMirrorSwitch(
      value: visibleConfig.mirrorToLocal,
      onChanged: (value) =>
          onChanged(visibleConfig.copyWith(mirrorToLocal: value)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    bgDropdown,
                    const SizedBox(height: 12),
                    mirrorSwitch,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: treatmentsDropdown),
              const SizedBox(width: 12),
              Expanded(child: pumpStatusDropdown),
              const SizedBox(width: 12),
              Expanded(child: historyDropdown),
            ],
          );
        }

        return Column(
          children: [
            bgDropdown,
            const SizedBox(height: 12),
            treatmentsDropdown,
            const SizedBox(height: 12),
            pumpStatusDropdown,
            const SizedBox(height: 12),
            historyDropdown,
            const SizedBox(height: 12),
            mirrorSwitch,
          ],
        );
      },
    );
  }
}
