import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/device_status_dashboard.dart';
import 'package:diabeatthis/foreground/providers/blood_sugar_value_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'foreground_task_event_test_host.dart';
import 'foreground_to_ui_test_router.dart';

/// Mounts the production display and production UI message handler.
class ForegroundGlucoseTestView extends ConsumerWidget {
  const ForegroundGlucoseTestView({
    required this.transport,
    this.showDeviceStatus = false,
    super.key,
  });
  final ForegroundToUiTestRouter transport;
  final bool showDeviceStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceStatusUiProvider);
    return ForegroundTaskEventTestHost(
      transport: transport,
      child: Scaffold(
        body: showDeviceStatus && device != null
            ? DeviceStatusDashboard(deviceStatus: device)
            : DashboardGlucoseReading(
                value: ref.watch(bloodSugarValueProvider)?.sgv,
                color: Colors.black,
                trendIcon: null,
              ),
      ),
    );
  }
}
