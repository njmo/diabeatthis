import 'package:flutter/material.dart';

import '../../../../common/history/glucose_window_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/theme/glucose_range_colors.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/chart_color_label.dart';
import '../../../../common/widgets/glucose_range_bar.dart';
import '../formatters/day_stat_formatter.dart';

class DayGlucoseRanges extends StatelessWidget {
  final GlucoseWindowSummary summary;
  const DayGlucoseRanges({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final palette = GlucoseRangeColors(Theme.of(context).brightness);
    String label(String name, Duration duration) {
      final value = summary.percent(duration);
      final percent = format.percent(value);
      return '$name · $percent · ${formatDurationLabel(duration)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlucoseRangeBar(summary: summary, height: 14),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            ChartColorLabel(
              color: palette.inRange,
              label: label(lang.dayInRange, summary.inRange),
            ),
            ChartColorLabel(
              color: palette.aboveRange,
              label: label(lang.dayAboveRange, summary.aboveRange),
            ),
            ChartColorLabel(
              color: palette.belowRange,
              label: label(lang.dayBelowRange, summary.belowRange),
            ),
            if (summary.missing > Duration.zero)
              ChartColorLabel(
                color: palette.missing,
                label:
                    '${lang.dayMissingGlucose} · ${formatDurationLabel(summary.missing)}',
              ),
          ],
        ),
      ],
    );
  }
}
