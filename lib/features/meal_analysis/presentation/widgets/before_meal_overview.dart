import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/glucose_summary_metric.dart';
import '../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../common/charts/meal_target_preparation_range.dart';
import '../../common/controllers/before_meal_overview_controller.dart';
import '../../common/widgets/meal_target_preparation_note.dart';
import '../../domain/models/before_meal_context.dart';
import 'before_meal_details_card.dart';
import 'before_meal_history_facts.dart';
import 'before_meal_rescue_suggestion_card.dart';

class BeforeMealOverview extends StatelessWidget {
  const BeforeMealOverview({
    super.key,
    required this.data,
    required this.hasRecordedStart,
  });
  final BeforeMealContext data;
  final bool hasRecordedStart;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    final time = DateFormat('HH:mm', lang.localeName);
    final review = const BeforeMealOverviewController().build(
      data,
      hasRecordedStart: hasRecordedStart,
    );
    final preparation = review.preparation;
    final status = data.latestDeviceStatus;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryDetailCard(
          title: lang.mealJustBefore,
          icon: Icons.history,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${hasRecordedStart ? lang.mealReviewRecordedStart : lang.mealReviewFallbackStart}: ${time.format(data.asOf.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!hasRecordedStart) Text(lang.mealReviewFallbackContext),
              const SizedBox(height: 12),
              GlucoseSummaryMetric(
                glucose: data.latestCgm,
                detail: data.latestCgm == null
                    ? null
                    : '${time.format(data.latestCgm!.date.toLocal())} · ${data.hasFreshCgm ? lang.beforeMealFresh : lang.beforeMealStale}',
              ),
              if (data.glucose?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                TimelineAnalysisCharts(
                  chartStart: data.asOf.subtract(data.windows.glucose),
                  chartEnd: data.asOf,
                  glucoseReadings: data.glucose!,
                  deviceStatuses: const [],
                  fitToWidth: true,
                  showDeviceMetrics: false,
                  overviewStyle: true,
                  ranges: [
                    if (preparation != null)
                      mealTargetPreparationRange(
                        preparation,
                        lang,
                        colors.primary,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ResponsiveMetricList(
                maxColumns: 2,
                minimumWidth: 120,
                children: [
                  NutritionSummaryMetric(
                    label: lang.dashboardIobLabel,
                    value: status?.hasIob == true
                        ? '${number.format(status!.iob)} U'
                        : lang.beforeMealUnavailable,
                    icon: Icons.water_drop_outlined,
                    color: colors.primary,
                    detail: status == null
                        ? null
                        : time.format(status.date.toLocal()),
                  ),
                  NutritionSummaryMetric(
                    label: lang.dashboardCobLabel,
                    value: status?.hasCob == true
                        ? '${number.format(status!.cob)} g'
                        : lang.beforeMealUnavailable,
                    icon: Icons.restaurant_outlined,
                    color: colors.tertiary,
                  ),
                ],
              ),
              if (preparation != null) ...[
                const SizedBox(height: 12),
                MealTargetPreparationNote(preparation: preparation),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        BeforeMealRescueSuggestionCard(suggestion: review.carbsSuggestion),
        BeforeMealHistoryFacts(data: data, precedingMealOnly: true),
        const SizedBox(height: 12),
        BeforeMealDetailsCard(data: data),
      ],
    );
  }
}
