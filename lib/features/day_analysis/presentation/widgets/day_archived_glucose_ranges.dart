import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/theme/glucose_range_colors.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_amount_breakdown.dart';

/// Like the live range bar, widths cover the entire window, including gaps.
/// Legend percentages continue to describe only the observed glucose history.
class DayArchivedGlucoseRanges extends StatelessWidget {
  final double? coverage;
  final double? inRange;
  final double? aboveRange;
  final double? belowRange;

  const DayArchivedGlucoseRanges({
    super.key,
    required this.coverage,
    required this.inRange,
    required this.aboveRange,
    required this.belowRange,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final colors = GlucoseRangeColors(Theme.of(context).brightness);
    final knownCoverage =
        coverage != null &&
        coverage!.isFinite &&
        coverage! >= 0 &&
        coverage! <= 100;
    double? width(double? observedPercent) {
      if (!knownCoverage) return null;
      if (coverage == 0) return 0;
      return observedPercent == null ? null : observedPercent * coverage! / 100;
    }

    final missing = knownCoverage ? 100 - coverage! : null;
    return DayAmountBreakdown(
      segments: [
        (
          label: lang.dayInRange,
          value: format.percent(inRange, decimals: 1),
          amount: width(inRange),
          color: colors.inRange,
        ),
        (
          label: lang.dayAboveRange,
          value: format.percent(aboveRange, decimals: 1),
          amount: width(aboveRange),
          color: colors.aboveRange,
        ),
        (
          label: lang.dayBelowRange,
          value: format.percent(belowRange, decimals: 1),
          amount: width(belowRange),
          color: colors.belowRange,
        ),
        if (missing == null || missing > 0)
          (
            label: lang.dayMissingGlucose,
            value: format.percent(missing, decimals: 1),
            amount: missing,
            color: colors.missing,
          ),
      ],
    );
  }
}
