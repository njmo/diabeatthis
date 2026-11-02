import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/plan_actual_meter.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../data/models/meal_start_context_data.dart';

class MealWaitComparison extends StatelessWidget {
  final MealStartContextData data;
  final bool visual;

  const MealWaitComparison({
    super.key,
    required this.data,
    this.visual = false,
  });

  @override
  Widget build(BuildContext context) {
    final advice = data.details.advisorDecision;
    if (advice == null || advice.isManual || advice.initialWaitTime <= 0) {
      return const SizedBox.shrink();
    }
    final messages = context.lang;
    final proposed = Duration(minutes: advice.initialWaitTime);
    final actual = data.recordedWait;
    final difference = actual == null ? null : actual - proposed;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.mealWaitComparisonTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ResponsiveMetricList(
            maxColumns: 2,
            children: [
              AnalysisMetric(
                icon: Icons.hourglass_empty,
                label: messages.mealWaitProposed,
                value: formatDurationLabel(proposed),
              ),
              AnalysisMetric(
                icon: Icons.timer_outlined,
                label: messages.mealWaitActual,
                value: actual == null ? '—' : formatDurationLabel(actual),
                detail: actual == null
                    ? messages.mealReviewUnknownActualWait
                    : messages.mealWaitActualSource,
              ),
            ],
          ),
          if (visual && actual != null) ...[
            const SizedBox(height: 12),
            PlanActualMeter(
              planned: proposed.inSeconds.toDouble(),
              actual: actual.inSeconds.toDouble(),
              semanticLabel:
                  '${messages.mealWaitProposed}: ${formatDurationLabel(proposed)}; ${messages.mealWaitActual}: ${formatDurationLabel(actual)}',
            ),
          ],
          if (difference != null) ...[
            const SizedBox(height: 8),
            Text(
              difference == Duration.zero
                  ? messages.mealWaitMatched
                  : difference.isNegative
                  ? messages.mealWaitShorter(formatDurationLabel(difference))
                  : messages.mealWaitLonger(formatDurationLabel(difference)),
            ),
          ],
          if (advice.waitTimeIgnored) ...[
            const SizedBox(height: 8),
            Text(
              messages.mealWaitIgnored,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
