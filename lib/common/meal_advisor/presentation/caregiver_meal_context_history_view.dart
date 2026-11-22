import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../../widgets/inline_status_notice.dart';
import '../../widgets/timeline_analysis_charts.dart';
import '../context/caregiver_meal_context_history.dart';
import 'meal_decision_carbohydrate_notices.dart';
import 'meal_decision_context_metrics.dart';
import 'meal_decision_context_status.dart';

class CaregiverMealContextHistoryView extends StatelessWidget {
  const CaregiverMealContextHistoryView({
    super.key,
    required this.history,
    this.additionalNotices = const [],
    this.leadingContent,
  });
  final Widget? leadingContent;
  final List<Widget> additionalNotices;
  final CaregiverMealContextHistory history;

  @override
  Widget build(BuildContext context) {
    final start = history.start;
    final end = history.end;
    final readings = history.readings;
    final statuses = history.statuses;
    final glucose = readings.lastOrNull;
    final device = statuses.lastOrNull;
    final previous = readings.length > 1 ? readings[readings.length - 2] : null;
    final delta =
        glucose != null &&
            previous != null &&
            glucose.date.difference(previous.date) <=
                const Duration(minutes: 10)
        ? glucose.sgv - previous.sgv
        : null;
    String time(DateTime at) =>
        DateFormat.Hm(context.lang.localeName).format(at.toLocal());
    final color = Theme.of(context).colorScheme.primary;
    final targets = history.targets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MealDecisionContextStatus(
          syncedAt: history.syncedAt,
          glucoseAt: glucose?.date,
          iobAt: device?.hasIob == true && device!.iob.isFinite
              ? device.date
              : null,
          cobAt: device?.hasCob == true && device!.cob.isFinite
              ? device.date
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          context.lang.mealDecisionContextTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final window in targets) ...[
              InlineStatusNotice(
                icon: Icons.info_outline,
                message: context.lang.mealDecisionDemoTargetWindow(
                  '${window.target.targetBottom}–${window.target.targetTop}',
                  time(window.target.createdAt),
                  time(window.end),
                ),
              ),
              const SizedBox(height: 6),
            ],
            MealDecisionCarbohydrateNotices(
              treatments: history.treatments,
              now: history.asOf,
              until: history.asOf.add(const Duration(hours: 4)),
            ),
            for (final notice in additionalNotices) ...[
              const SizedBox(height: 8),
              notice,
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (leadingContent != null) ...[
          leadingContent!,
          const SizedBox(height: 12),
        ],
        MealDecisionContextMetrics(
          glucose: glucose,
          delta: delta,
          iob: device?.hasIob == true ? device!.iob : null,
          cob: device?.hasCob == true ? device!.cob : null,
        ),
        const SizedBox(height: 16),
        TimelineAnalysisCharts(
          chartStart: start,
          chartEnd: end,
          selectedTimestamp: history.asOf,
          fitToWidth: true,
          glucoseReadings: readings,
          deviceStatuses: statuses
              .where(
                (s) => s.hasIob && s.hasCob && s.iob.isFinite && s.cob.isFinite,
              )
              .toList(),
          events: [
            TimelineChartEvent(
              timestamp: history.asOf,
              icon: Icons.access_time,
              color: color,
              label: context.lang.mealDecisionDemoNow(time(history.asOf)),
            ),
          ],
          ranges: [
            for (final window in targets)
              TimelineChartRange(
                start: window.target.createdAt,
                end: window.end,
                color: Colors.grey,
                alpha: .16,
                label:
                    '${window.target.targetBottom}–${window.target.targetTop}',
                startIcon: Icons.info_outline,
                endIcon: Icons.info_outline,
                startLabel: context.lang.mealDecisionContextTarget,
                endLabel: context.lang.mealDecisionContextTarget,
              ),
          ],
        ),
      ],
    );
  }
}
