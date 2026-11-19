import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/presentation/dashboard/family_sync_ribbon.dart';
import '../../../../common/presentation/dashboard/glucose_freshness.dart';
import '../../../../common/presentation/dashboard/nightscout_panel_view.dart';
import '../../../dashboard/data/providers/time_now_provider.dart';
import '../../../dashboard/data/utils/nightscout_utils.dart';
import '../../../dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import '../../../dashboard/presentation/widgets/device_status_dashboard.dart';
import '../../../dashboard/presentation/widgets/glucose_dashboard.dart';
import '../../../low_treatment/domain/models/aaps_carbs_request_signal.dart';
import '../../../low_treatment/domain/use_cases/evaluate_aaps_carbs_request_use_case.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_suggestion_card.dart';
import '../../data/caregiver_visible_state_provider.dart';

class CaregiverNightscoutPanel extends ConsumerWidget {
  const CaregiverNightscoutPanel({
    super.key,
    this.syncBusy = false,
    this.syncFailed = false,
    this.syncReady = false,
    this.onLowTreatment,
  });
  final bool syncBusy;
  final bool syncFailed;
  final bool syncReady;
  final VoidCallback? onLowTreatment;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(caregiverVisibleStateProvider).snapshot;
    final readings = snapshot?.readings ?? [];
    final glucose = snapshot?.latestGlucose;
    final device = snapshot?.deviceStatus;
    final now = ref.watch(timeNowProvider).asData?.value ?? DateTime.now();
    final request = const EvaluateAapsCarbsRequestUseCase()(
      status: device,
      glucose: readings,
      now: now,
    );
    return NightscoutPanelView(
      syncRibbon: FamilySyncRibbon(
        compact: true,
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
              readingIsOld: dashboardGlucoseIsStale(glucose?.date, now),
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
      footer: request.type == AapsCarbsRequestSignalType.positive &&
              device != null && onLowTreatment != null
          ? LowTreatmentSuggestionCard(
              carbsReq: device.carbsReq,
              carbsReqWithin: device.carbsReqWithin,
              onAdd: onLowTreatment!,
            )
          : null,
    );
  }
}
