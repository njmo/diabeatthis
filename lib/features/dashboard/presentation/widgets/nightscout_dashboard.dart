import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foreground/providers/device_status_value_provider.dart';
import '../../data/providers/time_now_provider.dart';

import '../../data/utils/nightscout_utils.dart';
import 'device_status_dashboard.dart';

class NightscoutPanel extends ConsumerWidget {
  const NightscoutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceStatusValue = ref.watch(deviceStatusValueProvider);
    final timeNowStream = ref.watch(timeNowProvider);

    if (deviceStatusValue == null) return const CircularProgressIndicator();

    final lastUpdate = timeNowStream
        .whenData((data) => data.difference(deviceStatusValue.date))
        .value;

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RepaintBoundary(
                        child: Text(
                          formatAgo(lastUpdate ?? Duration.zero),
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  DeviceStatusDashboard(deviceStatus: deviceStatusValue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
