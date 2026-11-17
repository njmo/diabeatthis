import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../common/presentation/charts/draw_dashed_chart_line.dart';
import '../../../../../core/domain/model/glucose.dart';
import '../../../../day_analysis/domain/models/day_context.dart';

class CaregiverNightSummaryCard extends StatefulWidget {
  const CaregiverNightSummaryCard({
    super.key,
    required this.day,
  });

  final DayContext day;

  @override
  State<CaregiverNightSummaryCard> createState() =>
      _CaregiverNightSummaryCardState();
}

class _CaregiverNightSummaryCardState extends State<CaregiverNightSummaryCard> {
  Offset? _touchOffset;

  @override
  void didUpdateWidget(CaregiverNightSummaryCard oldWidget) {
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
  }) {
    return Expanded(
      child: Container(
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
            Icon(icon, size: 16, color: color),
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
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final nightStart =
        DateTime(day.start.year, day.start.month, day.start.day - 1, 22);
    final nightEnd = DateTime(day.start.year, day.start.month, day.start.day, 6);

    final n = day.nightGlucose;
    List<Glucose> readings = n?.window.readings ?? [];

    if (readings.isEmpty && day.glucose != null) {
      readings = day.glucose!.window.readings
          .where((r) => !r.date.isBefore(nightStart) && !r.date.isAfter(nightEnd))
          .toList();
    }

    int? tirPercent;
    int? lowPercent;
    int? highPercent;
    int? meanGlucose = n?.mean?.round();
    int? lowMinutes;
    int? minGlucose = readings.isNotEmpty ? readings.map((r) => r.sgv).reduce(math.min) : null;
    int? maxGlucose = readings.isNotEmpty ? readings.map((r) => r.sgv).reduce(math.max) : null;

    if (n != null && n.window.observed > Duration.zero) {
      final totalObs = n.window.observed.inMilliseconds;
      tirPercent = (n.window.inRange.inMilliseconds / totalObs * 100).round();
      lowPercent =
          (n.window.belowRange.inMilliseconds / totalObs * 100).round();
      highPercent =
          (n.window.aboveRange.inMilliseconds / totalObs * 100).round();
      lowMinutes = n.window.belowRange.inMinutes;
      meanGlucose = n.mean?.round() ?? meanGlucose;
    }

    final nightBasalUnits = day.nightBasal?.units;
    final hasData = readings.isNotEmpty || (n != null && n.window.observed > Duration.zero);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.06),
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
                        'Poprzednia noc (22:00 – 06:00)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: numColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? 'Podsumowanie 8h snu'
                            : 'Brak zarejestrowanych danych z poprzedniej nocy',
                        style: TextStyle(fontSize: 11, color: mutedColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. Kafelki metryk nocy w stylu pozostałych bloczków
            Row(
              children: [
                _buildNightPill(
                  title: 'TIR Nocy',
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
                const SizedBox(width: 6),
                _buildNightPill(
                  title: 'Średnia',
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
                const SizedBox(width: 6),
                _buildNightPill(
                  title: 'Min / Max',
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
                const SizedBox(width: 6),
                _buildNightPill(
                  title: 'Baza nocna',
                  value: nightBasalUnits != null
                      ? '${nightBasalUnits.toStringAsFixed(1)}j'
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
                    'Przebieg glikemii podczas snu (22:00 – 06:00)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: numColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 4. 8-godzinny wykres nocny (CustomPaint)
            GestureDetector(
              onPanDown: (d) => setState(() => _touchOffset = d.localPosition),
              onPanUpdate: (d) =>
                  setState(() => _touchOffset = d.localPosition),
              onPanEnd: (_) => setState(() => _touchOffset = null),
              onPanCancel: () => setState(() => _touchOffset = null),
              child: SizedBox(
                height: 145,
                width: double.infinity,
                child: CustomPaint(
                  painter: CaregiverNightGlucosePainter(
                    readings: readings,
                    nightStart: nightStart,
                    nightEnd: nightEnd,
                    isDark: isDark,
                    touchOffset: _touchOffset,
                  ),
                ),
              ),
            ),

            if (hasData && tirPercent != null) ...[
              const SizedBox(height: 10),

              // Pasek TIR nocy
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      if ((lowPercent ?? 0) > 0)
                        Expanded(
                          flex: math.max(1, lowPercent!),
                          child: Container(color: const Color(0xFFEF4444)),
                        ),
                      if (tirPercent! > 0)
                        Expanded(
                          flex: math.max(1, tirPercent!),
                          child: Container(color: const Color(0xFF10B981)),
                        ),
                      if ((highPercent ?? 0) > 0)
                        Expanded(
                          flex: math.max(1, highPercent!),
                          child: Container(color: const Color(0xFFF59E0B)),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Legenda zakresów nocy (odporna na overflow)
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '<70: ${lowPercent ?? 0}% (${lowMinutes ?? 0}m)',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'Norma: $tirPercent% (${((480 * tirPercent!) / (60 * 100)).toStringAsFixed(1)}h)',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '>180: ${highPercent ?? 0}%',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CaregiverNightGlucosePainter extends CustomPainter {
  final List<Glucose> readings;
  final DateTime nightStart;
  final DateTime nightEnd;
  final bool isDark;
  final Offset? touchOffset;

  CaregiverNightGlucosePainter({
    required this.readings,
    required this.nightStart,
    required this.nightEnd,
    required this.isDark,
    this.touchOffset,
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

    final double minY = 40.0;
    final double maxY = math.max(
      240.0,
      readings.isEmpty
          ? 240.0
          : ((readings.map((r) => r.sgv).reduce(math.max) + 19) ~/ 20) * 20.0,
    );

    double xForTime(DateTime t) {
      final diffMin = t.difference(nightStart).inSeconds / 60.0;
      final ratio = (diffMin / 480.0).clamp(0.0, 1.0); // 8h = 480 min
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
        ..color = const Color(0xFF6366F1).withValues(alpha: isDark ? 0.08 : 0.05),
    );

    // Strefa hipo < 70
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(chartArea.left, y70, chartArea.right, chartArea.bottom),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.08 : 0.05),
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
    final hours = [
      (0, '22:00'),
      (120, '00:00'),
      (240, '02:00'),
      (360, '04:00'),
      (480, '06:00'),
    ];

    for (final h in hours) {
      final t = nightStart.add(Duration(minutes: h.$1));
      final x = xForTime(t);

      // Północ ma specjalną subtelną linię
      final isMidnight = h.$1 == 120;
      canvas.drawLine(
        Offset(x, chartArea.top),
        Offset(x, chartArea.bottom),
        Paint()
          ..color = (isMidnight
                  ? const Color(0xFF818CF8)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)))
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

    // 3. Płynna krzywa nocna Beziera z podziałem na luki > 15 min
    if (readings.isNotEmpty) {
      final sortedReadings = List<Glucose>.from(readings)
        ..sort((a, b) => a.date.compareTo(b.date));

      final List<List<Offset>> segments = [];
      List<Offset> currentSegment = [];

      for (int i = 0; i < sortedReadings.length; i++) {
        final r = sortedReadings[i];
        final pt = Offset(xForTime(r.date), yForSgv(r.sgv.toDouble()));
        if (currentSegment.isEmpty) {
          currentSegment.add(pt);
        } else {
          final prev = sortedReadings[i - 1];
          if (r.date.difference(prev.date).inMinutes.abs() > 15) {
            segments.add(currentSegment);
            currentSegment = [pt];
          } else {
            currentSegment.add(pt);
          }
        }
      }
      if (currentSegment.isNotEmpty) segments.add(currentSegment);

      for (final segment in segments) {
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

          for (int i = 0; i < segment.length - 1; i++) {
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
        'Brak zarejestrowanych odczytów glikemii z nocy',
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
      double minD = double.infinity;
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
        canvas.drawCircle(
          Offset(rX, rY),
          2.0,
          Paint()..color = Colors.white,
        );

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
  bool shouldRepaint(covariant CaregiverNightGlucosePainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.nightStart != nightStart ||
        oldDelegate.nightEnd != nightEnd ||
        oldDelegate.isDark != isDark ||
        oldDelegate.touchOffset != touchOffset;
  }
}
