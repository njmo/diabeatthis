import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/domain/model/device_status.dart';
import '../../core/domain/model/glucose.dart';
import '../history/latest_reading_at.dart';
import '../l10n/language.dart';
import 'analysis_metric.dart';
import 'responsive_metric_list.dart';

class TimelineSelectionSummary extends StatelessWidget {
  final DateTime timestamp;
  final List<Glucose> glucoseReadings;
  final List<DeviceStatus> deviceStatuses;

  const TimelineSelectionSummary({
    super.key,
    required this.timestamp,
    required this.glucoseReadings,
    required this.deviceStatuses,
  });

  @override
  Widget build(BuildContext context) {
    final glucose = latestReadingAt(glucoseReadings, timestamp, (g) => g.date);
    final status = latestReadingAt(deviceStatuses, timestamp, (s) => s.date);
    final messages = context.lang;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd.MM · HH:mm').format(timestamp),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ResponsiveMetricList(
            children: [
              AnalysisMetric(
                label: messages.mealReviewGlucose,
                value: glucose == null ? '—' : '${glucose.sgv}',
                detail: glucose == null
                    ? messages.mealReviewNoNearbyReading
                    : DateFormat.Hm().format(glucose.date),
              ),
              if (status != null)
                AnalysisMetric(
                  label: messages.mealReviewIob,
                  value: '${status.iob.toStringAsFixed(1)} j.',
                  detail: DateFormat.Hm().format(status.date),
                ),
              if (status != null)
                AnalysisMetric(
                  label: messages.mealReviewCob,
                  value: '${status.cob.toStringAsFixed(0)} g',
                  detail: DateFormat.Hm().format(status.date),
                ),
            ],
          ),
          if (status == null) ...[
            const SizedBox(height: 12),
            Text(
              messages.mealReviewNoDeviceReading,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
