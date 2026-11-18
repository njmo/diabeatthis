import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/dashboard/family_sync_ribbon.dart';
import '../../../../common/presentation/dashboard/nightscout_panel_view.dart';
import '../../../dashboard/data/providers/time_now_provider.dart';
import '../../../dashboard/data/utils/nightscout_utils.dart';
import '../../../dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import '../../../dashboard/presentation/widgets/dashboard_target_progress.dart';
import '../../../dashboard/presentation/widgets/device_status_dashboard.dart';
import '../../../dashboard/presentation/widgets/glucose_dashboard.dart';
import '../../data/caregiver_visible_state_provider.dart';

class CaregiverNightscoutPanel extends ConsumerWidget {
  const CaregiverNightscoutPanel({
    super.key,
    this.syncBusy = false,
    this.syncFailed = false,
    this.syncReady = false,
  });
  final bool syncBusy;
  final bool syncFailed;
  final bool syncReady;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(caregiverVisibleStateProvider).snapshot;
    final readings = snapshot?.readings ?? [];
    final glucose = snapshot?.latestGlucose;
    final device = snapshot?.deviceStatus;
    final target = snapshot?.temporaryTarget;
    final now = ref.watch(timeNowProvider).asData?.value ?? DateTime.now();
    return NightscoutPanelView(
      syncRibbon: FamilySyncRibbon(
        busy: syncBusy,
        failed: syncFailed,
        ready: syncReady,
      ),
      lastUpdate: glucose == null
          ? null
          : formatAgo(now.difference(glucose.date)),
      readings: device != null
          ? DeviceStatusDashboard(
              deviceStatus: device,
              allowLocalActions: false,
              useDeviceGlucose: false,
              glucose: glucose,
              readingIsOld:
                  glucose == null ||
                  now.difference(glucose.date).inMinutes > 10,
              readings: readings,
            )
          : glucose != null
          ? GlucoseDashboard(glucose: glucose, readings: readings)
          : DashboardGlucoseReading(
              readings: const [],
              value: null,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              trendIcon: null,
            ),
      footer:
          target != null &&
              target.isValid &&
              target.createdAt
                  .add(Duration(minutes: target.duration))
                  .isAfter(now) &&
              !target.createdAt.isAfter(now) &&
              target.targetBottom > 0 &&
              target.targetTop >= target.targetBottom
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.lang.caregiverTargetRange(
                      target.targetBottom.toString(),
                      target.targetTop.toString(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DashboardTargetProgress(target: target, now: now),
                ],
              ),
            )
          : null,
    );
  }
}
