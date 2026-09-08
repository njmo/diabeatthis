import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../../../common/widgets/glucose_direction_icon.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../data/models/meal_start_context_data.dart';
import 'meal_detail_formatters.dart';
import 'meal_wait_comparison.dart';

class MealStartContextSection extends StatelessWidget {
  final MealStartContextData data;

  const MealStartContextSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final messages = context.lang;
    final glucose = data.glucose;
    final device = data.deviceStatus;
    final bolus = data.precedingBolus;
    final wait = data.bolusToStart;
    String units(double value) =>
        '${NumberFormat('0.##', messages.localeName).format(value)} j.';
    return DetailSectionCard(
      title: messages.mealReviewStartingContext,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data.hasRecordedStart ? messages.mealReviewRecordedStart : messages.mealReviewFallbackStart} · '
                '${mealTime(data.referenceTime)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ResponsiveMetricList(
                maxColumns: 3,
                minimumWidth: 80,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.textScalerOf(context).scale(32),
                        ),
                        child: Text(
                          messages.mealReviewGlucose,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            glucose?.sgv.toString() ?? '—',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Icon(
                            iconForDirection(glucose?.direction),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      Text(
                        directionLabel(context, glucose?.direction),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  AnalysisMetric(
                    labelLines: 2,
                    label: messages.mealReviewIob,
                    value: device == null ? '—' : units(device.iob),
                    detail: device == null
                        ? messages.mealReviewNoNearbyReading
                        : mealTime(device.date),
                  ),
                  AnalysisMetric(
                    labelLines: 2,
                    label: messages.mealReviewBolusToStart,
                    value: wait == null ? '—' : formatDurationLabel(wait),
                    detail: wait == null
                        ? messages.mealReviewUnknownActualWait
                        : '${mealTime(bolus!.createdAt)}–${mealTime(data.referenceTime)}',
                  ),
                ],
              ),
              if (bolus != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${messages.mealReviewLastManualBolus}: ${units(bolus.insulin)} · ${mealTime(bolus.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              MealWaitComparison(data: data),
              if (!data.hasRecordedStart) ...[
                const SizedBox(height: 12),
                Text(
                  messages.mealReviewFallbackContext,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String directionLabel(BuildContext context, String? direction) =>
      switch (direction) {
        'DoubleUp' ||
        'SingleUp' ||
        'FortyFiveUp' => context.lang.mealReviewRising,
        'DoubleDown' ||
        'SingleDown' ||
        'FortyFiveDown' => context.lang.mealReviewFalling,
        'Flat' => context.lang.mealReviewSteady,
        _ => context.lang.mealReviewUnknownTrend,
      };
}
