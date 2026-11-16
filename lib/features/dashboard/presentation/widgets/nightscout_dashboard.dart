import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/family_sync/presentation/child_family_cloud_ribbon.dart';
import '../../../../common/presentation/dashboard/nightscout_panel_view.dart';
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

    return NightscoutPanelView(
      syncRibbon: const ChildFamilyCloudRibbon(),
      lastUpdate: readingDate == null
          ? null
          : formatAgo(lastUpdate ?? Duration.zero),
      readings: deviceStatusValue != null
          ? DeviceStatusDashboard(deviceStatus: deviceStatusValue)
          : glucoseValue != null
          ? GlucoseDashboard(
              glucose: glucoseValue,
            )
          : DashboardGlucoseReading(
              value: null,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              trendIcon: null,
            ),
    );
  }
}
