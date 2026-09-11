import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/history/glucose_rise_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/chart_color_label.dart';
import '../../../../../common/widgets/glucose_range_bar.dart';
import '../../../../meal_analysis/domain/models/meal_glucose_analysis.dart';
import '../../../../meal_analysis/domain/services/meal_glucose_observation.dart';
import '../../../common/formatters/format_meal_rise_timing.dart';
import '../../../common/theme/analysis_chart_colors.dart';

class SimilarMealGlucoseSummary extends StatelessWidget {
  final MealGlucoseAnalysis data;
  const SimilarMealGlucoseSummary({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final summary = data.glucoseSummary;
    final window = summary.window;
    final number = NumberFormat('0.#', lang.localeName);
    final palette = AnalysisChartColors(Theme.of(context).brightness);
    final elapsed = window.end.difference(window.start).inMilliseconds;
    String percent(Duration duration) {
      final value = window.percent(duration);
      return value == null ? '—' : '${number.format(value)}%';
    }

    final missingPercent = elapsed <= 0
        ? '—'
        : '${number.format(window.missing.inMilliseconds / elapsed * 100)}%';
    final rise = GlucoseRiseSummary.fromReadings(window.readings);
    final absence = formatMealRiseAbsence(
      rise,
      window,
      lang,
      complete: data.isTimeWindowComplete,
    );
    final riseText = rise.startedAt != null
        ? formatMealRiseTiming(rise, data.mealTime, lang)
        : hasCompleteMealRiseObservation(
            rise,
            window,
            complete: data.isTimeWindowComplete,
          )
        ? absence
        : '—';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.mealRangeObservedBasis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          GlucoseRangeBar(summary: window),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              ChartColorLabel(
                color: palette.inRange,
                label: '70–180: ${percent(window.inRange)}',
              ),
              ChartColorLabel(
                color: palette.belowRange,
                label: '<70: ${percent(window.belowRange)}',
              ),
              ChartColorLabel(
                color: palette.aboveRange,
                label: '>180: ${percent(window.aboveRange)}',
              ),
              if (window.missing > Duration.zero)
                ChartColorLabel(
                  color: palette.missing,
                  label: '${lang.similarMealMissing}: $missingPercent',
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              Text(
                lang.similarMealMean(
                  summary.mean == null ? '—' : number.format(summary.mean),
                ),
              ),
              Text(lang.similarMealMaximum(window.peak?.sgv.toString() ?? '—')),
              Tooltip(
                message: rise.startedAt == null
                    ? absence
                    : lang.mealResponseRiseMethod,
                child: Text(lang.similarMealRise(riseText)),
              ),
            ],
          ),
          if (!data.isTimeWindowComplete)
            Text(
              lang.mealOutcomeWindowPartial,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}
