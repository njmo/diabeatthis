import 'package:flutter/material.dart';

import '../../../features/day_analysis/domain/models/day_context.dart';
import '../../l10n/language.dart';
import '../../widgets/data_warning_indicator.dart';
import '../../widgets/responsive_metric_list.dart';
import 'day_insulin_summary.dart';

class DayQuickMetrics extends StatelessWidget {
  const DayQuickMetrics({super.key, required this.day});
  final DayContext day;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final numColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final g = day.glucose;
    int? tir;
    final mean = g?.mean?.round();
    final lowMin = g != null && g.window.observed > Duration.zero
        ? g.window.belowRange.inMinutes
        : null;

    if (g != null && g.window.observed > Duration.zero) {
      tir =
          (g.window.inRange.inMilliseconds /
                  g.window.observed.inMilliseconds *
                  100)
              .round();
    }

    final insulin = DayInsulinSummary(boluses: day.boluses, basal: day.basal);
    final totalInsulin = insulin.totalUnits;
    final insulinWarnings = insulin.warnings(context.lang);

    Widget buildPill(
      String title,
      String value,
      Color color,
      IconData icon, {
      String? warning,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  if (warning != null)
                    DataWarningIndicator(message: warning, compact: true),
                ],
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: numColor,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }

    return ResponsiveMetricList(
      maxColumns: 4,
      minimumWidth: 72,
      spacing: 6,
      runSpacing: 8,
      equalRowHeights: true,
      children: [
        buildPill(
          context.lang.dayCompactTir,
          tir != null ? '$tir%' : '--',
          (tir ?? 0) >= 70 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          Icons.track_changes_rounded,
        ),
        buildPill(
          context.lang.dayGlucoseMean,
          mean != null ? '$mean' : '--',
          const Color(0xFF00A3FF),
          Icons.bloodtype_outlined,
        ),
        buildPill(
          context.lang.dayCompactLow,
          lowMin != null ? '${lowMin}m' : '--',
          (lowMin ?? 0) > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          Icons.warning_amber_rounded,
        ),
        buildPill(
          context.lang.dayInsulinTitle,
          totalInsulin != null ? '${totalInsulin.toStringAsFixed(1)} U' : '--',
          const Color(0xFF8B5CF6),
          Icons.medication_liquid_outlined,
          warning: insulinWarnings.isEmpty ? null : insulinWarnings.join('\n'),
        ),
      ],
    );
  }
}
