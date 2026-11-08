import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../l10n/language.dart';
import '../../../widgets/inline_status_notice.dart';
import '../../../widgets/timeline_analysis_charts.dart';
import '../../demo/meal_decision_demo_snapshot.dart';
import '../meal_decision_context_status.dart';

/// An explicitly simulated 30-minute series ending at the sample snapshot.
/// Never mixes sample meal data with a real child's health readings.
class MealDecisionDemoGlucoseHistory extends StatelessWidget {
  const MealDecisionDemoGlucoseHistory({
    super.key,
    required this.snapshot,
    this.leading,
  });
  final Widget? leading;
  final MealDecisionDemoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final start = snapshot.capturedAt.subtract(const Duration(minutes: 30));
    final end = snapshot.capturedAt.add(const Duration(minutes: 5));
    final targetStart =
        snapshot.targetStartedAt ??
        snapshot.capturedAt.subtract(const Duration(minutes: 15));
    final targetEnd =
        snapshot.targetEndedAt ??
        snapshot.capturedAt.add(const Duration(minutes: 15));
    final showTarget =
        snapshot.targetGlucose != null &&
        snapshot.targetGlucose!.isFinite &&
        snapshot.targetGlucose! > 0 &&
        targetStart.isBefore(targetEnd) &&
        targetEnd.isAfter(start) &&
        targetStart.isBefore(end) &&
        !targetStart.isAfter(snapshot.capturedAt);
    final targetActive = showTarget && targetEnd.isAfter(snapshot.capturedAt);
    final targetLabel = showTarget
        ? context.lang.mealDecisionDemoTargetWindow(
            NumberFormat.decimalPattern(
              context.lang.localeName,
            ).format(snapshot.targetGlucose),
            DateFormat.Hm(context.lang.localeName).format(targetStart),
            DateFormat.Hm(context.lang.localeName).format(targetEnd),
          )
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MealDecisionContextStatus(
          syncedAt: snapshot.capturedAt,
          glucoseAt: snapshot.capturedAt,
          iobAt: snapshot.capturedAt,
          cobAt: snapshot.capturedAt,
          referenceTime: snapshot.capturedAt,
          notices: [
            if (showTarget) ...[
              InlineStatusNotice(
                icon: Icons.info_outline,
                message: targetLabel,
              ),
            ],
            if (snapshot.extendedCarbsRemaining > 0 &&
                snapshot.extendedCarbsRemainingMinutes > 0) ...[
              InlineStatusNotice(
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.amber.shade700,
                message: context.lang.mealDecisionDemoOngoingCarbs(
                  NumberFormat.decimalPattern(
                    context.lang.localeName,
                  ).format(snapshot.extendedCarbsRemaining),
                  snapshot.extendedCarbsRemainingMinutes,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (leading != null) ...[leading!, const SizedBox(height: 16)],
        Text(
          context.lang.mealDecisionDemoGlucoseHistory,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.lang.mealDecisionDemoNoForecast,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TimelineAnalysisCharts(
          chartStart: snapshot.capturedAt.subtract(const Duration(minutes: 30)),
          chartEnd: snapshot.capturedAt.add(const Duration(minutes: 5)),
          selectedTimestamp: snapshot.capturedAt,
          targetGlucose: targetActive ? snapshot.targetGlucose : null,
          targetLabel: snapshot.targetGlucose == null
              ? null
              : context.lang.mealDecisionDemoTarget(
                  NumberFormat.decimalPattern(
                    context.lang.localeName,
                  ).format(snapshot.targetGlucose),
                ),
          ranges: [
            if (showTarget)
              TimelineChartRange(
                start: targetStart,
                end: targetEnd,
                color: Colors.grey,
                alpha: .16,
                label: targetLabel,
                startIcon: Icons.info_outline,
                endIcon: Icons.info_outline,
                startLabel: targetLabel,
                endLabel: targetLabel,
              ),
          ],
          events: [
            TimelineChartEvent(
              timestamp: snapshot.capturedAt,
              icon: Icons.access_time,
              color: Theme.of(context).colorScheme.primary,
              label: context.lang.mealDecisionDemoNow(
                DateFormat.Hm(
                  context.lang.localeName,
                ).format(snapshot.capturedAt),
              ),
            ),
          ],
          fitToWidth: true,
          overviewStyle: false,
          showDeviceMetrics: true,
          deviceStatuses: [
            for (var index = 0; index <= 6; index++)
              DeviceStatus(
                externalId: null,
                source: DeviceStatusSource.cloud,
                date: snapshot.capturedAt.subtract(
                  Duration(minutes: 30 - index * 5),
                ),
                iob: snapshot.iob + (6 - index) * .1,
                basalIob: 0,
                bolusIob: snapshot.iob + (6 - index) * .1,
                insulinActivity: 0,
                hasInsulinActivity: false,
                cob: snapshot.cob + (6 - index),
                tick: '${snapshot.delta}',
                bg: snapshot.glucose,
                carbsReq: 0,
                carbsReqWithin: 0,
                sensitivityRatio: 1,
                isfMgdlForCarbs: 0,
                baseBasalRate: 0,
                tempBasalRemainingMinutes: 0,
                lastBolusAmount: 0,
                lastBolusAt: '',
              ),
          ],
          glucoseReadings: [
            for (var index = 0; index <= 6; index++)
              Glucose(
                externalId: null,
                source: GlucoseSource.cloud,
                date: snapshot.capturedAt.subtract(
                  Duration(minutes: 30 - index * 5),
                ),
                sgv: snapshot.glucose - (6 - index) * snapshot.delta,
                direction: snapshot.direction,
              ),
          ],
        ),
      ],
    );
  }
}
