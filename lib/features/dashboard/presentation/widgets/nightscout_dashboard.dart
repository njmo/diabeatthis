import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foreground/providers/blood_sugar_value_provider.dart';
import '../../data/providers/device_status_ui_provider.dart';
import '../../data/providers/time_now_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'device_status_dashboard.dart';
import 'glucose_dashboard.dart';

class NightscoutPanel extends ConsumerWidget {
  const NightscoutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceStatusValue = ref.watch(deviceStatusUiProvider);
    final glucoseValue = ref.watch(bloodSugarValueProvider);
    final timeNowStream = ref.watch(timeNowProvider);

    if (deviceStatusValue == null && glucoseValue == null) {
      return const CircularProgressIndicator();
    }

    final readingDate = deviceStatusValue?.date ?? glucoseValue!.date;
    final lastUpdate = timeNowStream
        .whenData((data) => data.difference(readingDate))
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
                  if (deviceStatusValue != null)
                    DeviceStatusDashboard(deviceStatus: deviceStatusValue)
                  else
                    GlucoseDashboard(glucose: glucoseValue!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
