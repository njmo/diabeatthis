import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/dashboard/data/providers/time_now_provider.dart';
import '../../../features/day_analysis/domain/models/day_context.dart';
import '../../history/glucose_window_summary.dart';
import '../../l10n/language.dart';
import '../../utils/format_duration_label.dart';
import '../dashboard/glucose_freshness_provider.dart';
import 'day_chart_time.dart';

GlucoseWindowSummary? visibleDayGlucoseWindow(DayContext day, DateTime now) {
  final original = day.glucose?.window;
  if (original == null) return null;
  final dayEnd = dayChartClock(day.start, 0, dayOffset: 1);
  final candidate = !now.isBefore(dayEnd) ? original.end : now;
  final end = candidate.isAfter(dayEnd)
      ? dayEnd
      : candidate.isBefore(day.start)
      ? day.start
      : candidate;
  return GlucoseWindowSummary(
    readings: [
      if (original.baseline != null) original.baseline!,
      ...original.readings,
    ],
    start: day.start,
    end: end,
  );
}

bool showDayGlucoseCoverageWarning(
  DayContext day,
  GlucoseWindowSummary? window,
) =>
    window != null &&
    window.missing.inMicroseconds * 10 >
        dayChartClock(
          day.start,
          0,
          dayOffset: 1,
        ).difference(day.start).inMicroseconds;

class DayGlucoseCoverageWarning extends ConsumerWidget {
  const DayGlucoseCoverageWarning({super.key, required this.day});
  final DayContext day;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeNowProvider);
    final now = ref.watch(dashboardWallClockProvider)();
    final window = visibleDayGlucoseWindow(day, now);
    if (!showDayGlucoseCoverageWarning(day, window)) {
      return const SizedBox.shrink();
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFFDE68A) : const Color(0xFF854D0E);
    return Container(
      key: const ValueKey('day-glucose-coverage-warning'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: dark ? .16 : .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: .4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${context.lang.dayMissingGlucose} · ${formatDurationLabel(window!.missing)}',
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
