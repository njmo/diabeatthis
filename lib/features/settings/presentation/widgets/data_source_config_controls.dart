import 'package:flutter/material.dart';

import '../../../../core/data_sources/config/data_source_config.dart';
import 'data_source_dropdown.dart';
import 'data_source_mirror_switch.dart';
import 'data_source_option_labels.dart';

class DataSourceConfigControls extends StatelessWidget {
  const DataSourceConfigControls({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final DataSourceConfig config;
  final ValueChanged<DataSourceConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final bgDropdown = DataSourceDropdown<BgSource>(
      label: 'Cukier',
      value: config.bgSource,
      values: BgSource.values,
      labelFor: (source) => source.label,
      onChanged: (source) => onChanged(config.copyWith(bgSource: source)),
    );
    final eventDropdown = DataSourceDropdown<EventSource>(
      label: 'Zdarzenia',
      value: config.eventSource,
      values: EventSource.values,
      labelFor: (source) => source.label,
      onChanged: (source) => onChanged(config.copyWith(eventSource: source)),
    );
    final pumpStatusDropdown = DataSourceDropdown<PumpStatusSource>(
      label: 'Status pompy',
      value: config.pumpStatusSource,
      values: PumpStatusSource.values,
      labelFor: (source) => source.label,
      onChanged: (source) =>
          onChanged(config.copyWith(pumpStatusSource: source)),
    );
    final historyDropdown = DataSourceDropdown<HistorySource>(
      label: 'Historia',
      value: config.historySource,
      values: HistorySource.values,
      labelFor: (source) => source.label,
      onChanged: (source) => onChanged(config.copyWith(historySource: source)),
    );
    final mirrorSwitch = DataSourceMirrorSwitch(
      value: config.mirrorToLocal,
      onChanged: (value) => onChanged(config.copyWith(mirrorToLocal: value)),
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
              Expanded(child: eventDropdown),
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
            eventDropdown,
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
