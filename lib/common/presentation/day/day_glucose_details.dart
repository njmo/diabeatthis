import 'package:flutter/material.dart';

import '../../../features/day_analysis/presentation/widgets/day_glucose_ranges.dart';
import '../../history/glucose_period_summary.dart';
import '../../l10n/language.dart';
import '../../widgets/data_warning_indicator.dart';
import '../../widgets/responsive_bottom_sheet.dart';
import 'day_stat_formatter.dart';

/// Exact measured coverage and durations, independent of the chart's styling.
class DayGlucoseDetails extends StatelessWidget {
  const DayGlucoseDetails({
    super.key,
    required this.summary,
    this.isNight = false,
  });
  final GlucosePeriodSummary? summary;
  final bool isNight;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final data = summary;
    final warning = data == null
        ? lang.daySourceUnavailable
        : data.window.observed == Duration.zero
        ? lang.dayNoGlucoseObservation
        : data.expectedReadingCount > 0 &&
              data.missingReadingCount * 10 >= data.expectedReadingCount
        ? lang.dayWarningMissingReadings(
            data.missingReadingCount,
            data.expectedReadingCount,
            format.number(
              data.missingReadingCount * 100 / data.expectedReadingCount,
            ),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${lang.dayCoverage}: ${format.percent(data?.coveragePercent)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: lang.dayReviewDetails,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => showResponsiveBottomSheet<void>(
                context: context,
                showDragHandle: true,
                useSafeArea: true,
                builder: (_) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text(
                    [
                      if (isNight) lang.dayNightNote,
                      lang.dayGlucoseMethod,
                      lang.dayGlucoseBarBasis,
                    ].join('\n\n'),
                  ),
                ),
              ),
            ),
            if (warning != null) DataWarningIndicator(message: warning),
          ],
        ),
        if (data == null || data.window.observed == Duration.zero)
          Text(warning!),
        if (data != null) DayGlucoseRanges(summary: data.window),
      ],
    );
  }
}
