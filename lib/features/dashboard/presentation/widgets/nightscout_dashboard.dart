import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../foreground/providers/blood_sugar_value_provider.dart';
import '../../data/providers/device_status_ui_provider.dart';
import '../../data/providers/time_now_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'dashboard_glucose_reading.dart';
import 'device_status_dashboard.dart';
import 'glucose_dashboard.dart';

class NightscoutPanel extends ConsumerWidget {
  const NightscoutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceStatusValue = ref.watch(deviceStatusUiProvider);
    final glucoseValue = ref.watch(bloodSugarValueProvider);
    final timeNowStream = ref.watch(timeNowProvider);

    final readingDate = deviceStatusValue?.date ?? glucoseValue?.date;
    final lastUpdate = timeNowStream
        .whenData(
          (data) => readingDate == null ? null : data.difference(readingDate),
        )
        .value;

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RepaintBoundary(
                        child: Text(
                          readingDate == null
                              ? context.lang.dashboardWaitingForData
                              : formatAgo(lastUpdate ?? Duration.zero),
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (deviceStatusValue != null)
                    DeviceStatusDashboard(deviceStatus: deviceStatusValue)
                  else if (glucoseValue != null)
                    GlucoseDashboard(glucose: glucoseValue)
                  else
                    DashboardGlucoseReading(
                      value: null,
                      color: theme.colorScheme.onSurfaceVariant,
                      trendIcon: null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
