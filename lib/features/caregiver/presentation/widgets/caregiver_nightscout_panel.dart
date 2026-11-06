import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/monitoring/widgets/insulin_carbohydrate_metrics.dart';
import '../../../dashboard/data/providers/time_now_provider.dart';
import '../../../dashboard/data/utils/nightscout_utils.dart';
import '../../../dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import '../../../dashboard/presentation/widgets/glucose_dashboard.dart';
import '../../data/caregiver_visible_state_provider.dart';

class CaregiverNightscoutPanel extends ConsumerWidget {
  const CaregiverNightscoutPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(caregiverVisibleStateProvider).snapshot;
    final readings = snapshot?.readings ?? [];
    final glucose = snapshot?.latestGlucose;
    final device = snapshot?.deviceStatus;
    final target = snapshot?.temporaryTarget;
    final now = ref.watch(timeNowProvider).asData?.value ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                glucose == null
                    ? context.lang.dashboardWaitingForData
                    : formatAgo(now.difference(glucose.date)),
              ),
              const SizedBox(height: 8),
              if (glucose != null)
                GlucoseDashboard(glucose: glucose, readings: readings)
              else
                DashboardGlucoseReading(
                  readings: const [],
                  value: null,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  trendIcon: null,
                ),
              if (device != null) ...[
                const Divider(height: 28),
                InsulinCarbohydrateMetrics(
                  iob: device.iob,
                  cob: device.cob,
                  hasIob: device.hasIob,
                  hasCob: device.hasCob,
                ),
                const SizedBox(height: 8),
                Text(
                  context.lang.caregiverDeviceReadingAge(
                    formatAgo(now.difference(device.date)),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (target != null &&
                  target.isValid &&
                  target.isActive() &&
                  !target.createdAt.isAfter(now) &&
                  target.targetBottom > 0 &&
                  target.targetTop >= target.targetBottom) ...[
                const Divider(height: 28),
                Text(
                  context.lang.caregiverTargetRange(
                    target.targetBottom.toString(),
                    target.targetTop.toString(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
