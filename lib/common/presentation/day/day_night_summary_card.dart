import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/domain/model/glucose.dart';
import '../../../features/day_analysis/domain/models/day_context.dart';
import '../../l10n/language.dart';
import '../../widgets/data_warning_indicator.dart';
import '../../widgets/responsive_metric_list.dart';
import '../charts/draw_dashed_chart_line.dart';
import 'day_chart_time.dart';
import 'day_glucose_details.dart';
import 'day_insulin_summary.dart';

class DayNightSummaryCard extends StatefulWidget {
  const DayNightSummaryCard({super.key, required this.day});

  final DayContext day;

  @override
  State<DayNightSummaryCard> createState() => _DayNightSummaryCardState();
}

class _DayNightSummaryCardState extends State<DayNightSummaryCard> {
  Offset? _touchOffset;

  @override
  void didUpdateWidget(DayNightSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day.start != widget.day.start) {
      _touchOffset = null;
    }
  }

  Widget _buildNightPill({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
    required Color numColor,
    required Color mutedColor,
    required Color borderColor,
    String? warning,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF4338CA).withValues(alpha: 0.4)
        : const Color(0xFFE0E7FF);
    final numColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final nightStart = DateTime(
      day.start.year,
      day.start.month,
      day.start.day - 1,
      22,
    );
    final nightEnd = DateTime(
      day.start.year,
      day.start.month,
      day.start.day,
      6,
    );

    final n = day.nightGlucose;
    final readings = n?.window.readings ?? [];

    int? tirPercent;
    var meanGlucose = n?.mean?.round();
    final minGlucose = readings.isNotEmpty
        ? readings.map((r) => r.sgv).reduce(math.min)
        : null;
    final maxGlucose = readings.isNotEmpty
        ? readings.map((r) => r.sgv).reduce(math.max)
        : null;

    if (n != null && n.window.observed > Duration.zero) {
      final totalObs = n.window.observed.inMilliseconds;
      tirPercent = (n.window.inRange.inMilliseconds / totalObs * 100).round();
      meanGlucose = n.mean?.round() ?? meanGlucose;
    }

    final insulin = DayInsulinSummary(
      boluses: day.nightBoluses,
      basal: day.nightBasal,
    );
    final nightBasalUnits = insulin.basalUnits;
    final insulinWarnings = insulin.warnings(context.lang, isNight: true);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF6366F1,
            ).withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Nagłówek karty (zawsze widoczny, nierozwijany)
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    size: 18,
                    color: Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.lang.dayNightTitle,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: numColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. Kafelki metryk nocy w stylu pozostałych bloczków
            ResponsiveMetricList(
              maxColumns: 4,
              minimumWidth: 64,
              spacing: 6,
              runSpacing: 8,
              equalRowHeights: true,
              children: [
                _buildNightPill(
                  title: context.lang.dayCompactTir,
                  value: tirPercent != null ? '$tirPercent%' : '--',
                  color: (tirPercent ?? 0) >= 70
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  icon: Icons.track_changes_rounded,
                  isDark: isDark,
                  numColor: numColor,
                  mutedColor: mutedColor,
                  borderColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
                _buildNightPill(
                  title: context.lang.dayGlucoseMean,
                  value: meanGlucose != null ? '$meanGlucose' : '--',
                  color: const Color(0xFF00A3FF),
                  icon: Icons.bloodtype_outlined,
                  isDark: isDark,
                  numColor: numColor,
                  mutedColor: mutedColor,
                  borderColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
                _buildNightPill(
                  title: context.lang.dayGlucoseExtremes,
                  value: (minGlucose != null && maxGlucose != null)
                      ? '$minGlucose–$maxGlucose'
                      : '--',
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.swap_vert_rounded,
                  isDark: isDark,
                  numColor: numColor,
                  mutedColor: mutedColor,
                  borderColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
                _buildNightPill(
                  title: context.lang.dayCompactNightBasal,
                  warning: insulinWarnings.isEmpty
                      ? null
                      : insulinWarnings.join('\n'),
                  value: nightBasalUnits != null
                      ? '${nightBasalUnits.toStringAsFixed(1)} U'
                      : '--',
                  color: const Color(0xFFEC4899),
                  icon: Icons.medication_liquid_outlined,
                  isDark: isDark,
                  numColor: numColor,
                  mutedColor: mutedColor,
                  borderColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 3. Etykieta wykresu nocy
            Row(
              children: [
                const Icon(
                  Icons.bedtime_rounded,
                  size: 14,
                  color: Color(0xFF818CF8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.lang.dayNightGlucoseChart,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: numColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 4. 8-godzinny wykres nocny (CustomPaint)
            GestureDetector(
              onHorizontalDragDown: (d) =>
                  setState(() => _touchOffset = d.localPosition),
              onHorizontalDragUpdate: (d) =>
                  setState(() => _touchOffset = d.localPosition),
              onHorizontalDragEnd: (_) => setState(() => _touchOffset = null),
              onHorizontalDragCancel: () => setState(() => _touchOffset = null),
              child: SizedBox(
                height: 145,
                width: double.infinity,
                child: CustomPaint(
                  painter: DayNightGlucosePainter(
                    readings: readings,
                    nightStart: nightStart,
                    nightEnd: nightEnd,
                    isDark: isDark,
                    touchOffset: _touchOffset,
                    noDataLabel: context.lang.dayNoGlucoseObservation,
                  ),
                ),
              ),
            ),

            DayGlucoseDetails(summary: n, isNight: true),
          ],
        ),
      ),
    );
  }
}

class DayNightGlucosePainter extends CustomPainter {
  final List<Glucose> readings;
  final DateTime nightStart;
  final DateTime nightEnd;
  final bool isDark;
  final Offset? touchOffset;
  final String noDataLabel;

  DayNightGlucosePainter({
    required this.readings,
    required this.nightStart,
    required this.nightEnd,
    required this.isDark,
    this.touchOffset,
    required this.noDataLabel,
  });

  static const double lowThreshold = 70.0;
  static const double targetLine = 110.0;
  static const double highThreshold = 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 6.0;
    const rightPad = 32.0;
    const topPad = 12.0;
    const bottomPad = 20.0;

    final chartArea = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    final minY = 40.0;
    final double maxY = math.max(
      240.0,
      readings.isEmpty
          ? 240.0
          : ((readings.map((r) => r.sgv).reduce(math.max) + 19) ~/ 20) * 20.0,
    );

    double xForTime(DateTime t) {
      final ratio = dayChartFraction(t, nightStart, nightEnd);
      return chartArea.left + ratio * chartArea.width;
    }

    double yForSgv(double sgv) {
      final clamped = sgv.clamp(minY, maxY);
      final ratio = (clamped - minY) / (maxY - minY);
      return chartArea.bottom - ratio * chartArea.height;
    }

    // 1. Korytarz normy 70–180 mg/dl z nocnym fioletowo-szmaragdowym odcieniem
    final y180 = yForSgv(highThreshold);
    final y70 = yForSgv(lowThreshold);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(chartArea.left, y180, chartArea.right, y70),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(
          0xFF6366F1,
        ).withValues(alpha: isDark ? 0.08 : 0.05),
    );

    // Strefa hipo < 70
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(chartArea.left, y70, chartArea.right, chartArea.bottom),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(
          0xFFEF4444,
        ).withValues(alpha: isDark ? 0.08 : 0.05),
    );

    // Linie 180, 110, 70
    drawDashedChartLine(
      canvas,
      Offset(chartArea.left, y180),
      Offset(chartArea.right, y180),
      Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
        ..strokeWidth = 0.8,
    );

    final y110 = yForSgv(targetLine);
    drawDashedChartLine(
      canvas,
      Offset(chartArea.left, y110),
      Offset(chartArea.right, y110),
      Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.35)
        ..strokeWidth = 0.7,
    );

    drawDashedChartLine(
      canvas,
      Offset(chartArea.left, y70),
      Offset(chartArea.right, y70),
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.4)
        ..strokeWidth = 0.8,
    );

    // Etykiety Y
    _drawText(
      canvas,
      '180',
      Offset(chartArea.right + 4, y180 - 5),
      const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: Color(0xFF10B981),
      ),
    );
    _drawText(
      canvas,
      '110',
      Offset(chartArea.right + 4, y110 - 5),
      TextStyle(
        fontSize: 8.5,
        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
      ),
    );
    _drawText(
      canvas,
      '70',
      Offset(chartArea.right + 4, y70 - 5),
      const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: Color(0xFFEF4444),
      ),
    );

    // 2. Oś czasu nocy co 2 godziny: 22:00, 00:00 (Północ), 02:00, 04:00, 06:00
    final hours = dayNightChartTicks(nightStart, nightEnd);

    for (final h in hours) {
      final t = h.$1;
      final x = xForTime(t);

      // Północ ma specjalną subtelną linię
      final isMidnight = t.hour == 0;
      canvas.drawLine(
        Offset(x, chartArea.top),
        Offset(x, chartArea.bottom),
        Paint()
          ..color =
              (isMidnight
                      ? const Color(0xFF818CF8)
                      : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF1F5F9)))
                  .withValues(alpha: isMidnight ? 0.4 : 0.5)
          ..strokeWidth = isMidnight ? 0.9 : 0.6,
      );

      _drawText(
        canvas,
        h.$2,
        Offset(x - 12, chartArea.bottom + 4),
        TextStyle(
          fontSize: 9,
          fontWeight: isMidnight ? FontWeight.w700 : FontWeight.w500,
          color: isMidnight
              ? const Color(0xFF818CF8)
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      );
    }

    // Each CGM sample covers at most five minutes.
    if (readings.isNotEmpty) {
      final sortedReadings = List<Glucose>.from(readings)
        ..sort((a, b) => a.date.compareTo(b.date));

      for (final readingsSegment in dayChartSegments(sortedReadings)) {
        final segment = readingsSegment
            .map((r) => Offset(xForTime(r.date), yForSgv(r.sgv.toDouble())))
            .toList();
        if (segment.length == 1) {
          // Pojedynczy punkt w luce
          canvas.drawCircle(
            segment.first,
            3.5,
            Paint()..color = const Color(0xFF818CF8),
          );
        } else {
          final path = Path();
          path.moveTo(segment.first.dx, segment.first.dy);

          for (var i = 0; i < segment.length - 1; i++) {
            final p0 = segment[i];
            final p1 = segment[i + 1];
            final midX = (p0.dx + p1.dx) / 2;
            path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
          }

          // Gradient nocny pod krzywą
          final fillPath = Path.from(path);
          fillPath.lineTo(segment.last.dx, chartArea.bottom);
          fillPath.lineTo(segment.first.dx, chartArea.bottom);
          fillPath.close();

          final fillPaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.18),
                const Color(0xFF6366F1).withValues(alpha: 0.0),
              ],
            ).createShader(chartArea);

          canvas.drawPath(fillPath, fillPaint);

          // Linia krzywej
          final strokePaint = Paint()
            ..color = const Color(0xFF818CF8)
            ..strokeWidth = 2.4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          canvas.drawPath(path, strokePaint);
        }
      }
    } else {
      _drawText(
        canvas,
        noDataLabel,
        Offset(chartArea.center.dx - 110, chartArea.center.dy - 6),
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      );
    }

    // 4. Dotyk / Scrubbing na wykresie nocy
    if (touchOffset != null && readings.isNotEmpty) {
      final touchX = touchOffset!.dx.clamp(chartArea.left, chartArea.right);

      Glucose? nearest;
      var minD = double.infinity;
      for (final r in readings) {
        final ptX = xForTime(r.date);
        final d = (ptX - touchX).abs();
        if (d < minD) {
          minD = d;
          nearest = r;
        }
      }

      // Pokazujemy dymek tylko jeśli dotyk jest blisko realnego odczytu (w promieniu 30px)
      if (nearest != null && minD < 30.0) {
        final rX = xForTime(nearest.date);
        final rY = yForSgv(nearest.sgv.toDouble());

        canvas.drawLine(
          Offset(rX, chartArea.top),
          Offset(rX, chartArea.bottom),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.0,
        );

        canvas.drawCircle(
          Offset(rX, rY),
          5.0,
          Paint()..color = const Color(0xFF818CF8),
        );
        canvas.drawCircle(Offset(rX, rY), 2.0, Paint()..color = Colors.white);

        final timeStr =
            '${nearest.date.hour.toString().padLeft(2, '0')}:${nearest.date.minute.toString().padLeft(2, '0')}';
        final text = '$timeStr · ${nearest.sgv} mg/dl';

        final ttW = 95.0;
        final ttH = 22.0;
        final ttX = (rX - ttW / 2).clamp(chartArea.left, chartArea.right - ttW);
        final ttY = math.max(chartArea.top, rY - 28);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(ttX, ttY, ttW, ttH),
            const Radius.circular(5),
          ),
          Paint()..color = const Color(0xFF1E1B4B),
        );

        _drawText(
          canvas,
          text,
          Offset(ttX + 8, ttY + 4),
          const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        );
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant DayNightGlucosePainter oldDelegate) {
    return oldDelegate.noDataLabel != noDataLabel ||
        oldDelegate.readings != readings ||
        oldDelegate.nightStart != nightStart ||
        oldDelegate.nightEnd != nightEnd ||
        oldDelegate.isDark != isDark ||
        oldDelegate.touchOffset != touchOffset;
  }
}
