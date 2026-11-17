import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../common/presentation/charts/draw_dashed_chart_line.dart';
import '../../../../../core/domain/model/glucose.dart';
import '../../../../day_analysis/domain/models/day_context.dart';

enum CaregiverChartStyle {
  smoothSpline,
  eventPins,
  clinicalDots,
}

class CaregiverChartEvent {
  final DateTime time;
  final String label;
  final String detail;
  final IconData icon;
  final Color color;

  const CaregiverChartEvent({
    required this.time,
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class CaregiverDayGlucoseChart extends StatefulWidget {
  const CaregiverDayGlucoseChart({
    super.key,
    required this.day,
    this.initialStyle = CaregiverChartStyle.smoothSpline,
    this.showStyleSelector = false,
  });

  final DayContext day;
  final CaregiverChartStyle initialStyle;
  final bool showStyleSelector;

  @override
  State<CaregiverDayGlucoseChart> createState() =>
      _CaregiverDayGlucoseChartState();
}

class _CaregiverDayGlucoseChartState extends State<CaregiverDayGlucoseChart> {
  late CaregiverChartStyle _style;
  Offset? _touchOffset;

  @override
  void initState() {
    super.initState();
    _style = widget.initialStyle;
  }

  @override
  void didUpdateWidget(CaregiverDayGlucoseChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day.start != widget.day.start) {
      _touchOffset = null;
    }
  }

  List<CaregiverChartEvent> _getEvents() {
    final day = widget.day;
    final events = <CaregiverChartEvent>[];

    // 1. Zdarzenia z Nightscout (jeśli istnieją w day)
    if (day.wizards != null && day.wizards!.isNotEmpty) {
      for (final w in day.wizards!) {
        final time = w.date ?? w.createdAt;
        final carbs = w.carbs;
        final insulin = w.insulin;
        if (carbs > 0 || insulin > 0) {
          final carbsStr = carbs > 0 ? '${carbs.round()}g' : '';
          final insStr = insulin > 0 ? '${insulin.toStringAsFixed(1)}j' : '';
          final detail = [carbsStr, insStr].where((s) => s.isNotEmpty).join(' · ');
          events.add(CaregiverChartEvent(
            time: time,
            label: carbs > 0 ? 'Posiłek' : 'Bolus',
            detail: detail,
            icon: carbs > 0 ? Icons.restaurant_rounded : Icons.vaccines_rounded,
            color: carbs > 0 ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
          ));
        }
      }
    }

    if (day.carbEntries != null && day.carbEntries!.isNotEmpty) {
      for (final t in day.carbEntries!) {
        if (t.carbs > 0 && !events.any((e) => e.time.difference(t.createdAt).abs().inMinutes < 5)) {
          events.add(CaregiverChartEvent(
            time: t.createdAt,
            label: 'Węglowodany',
            detail: '${t.carbs}g',
            icon: Icons.bakery_dining_rounded,
            color: const Color(0xFFF59E0B),
          ));
        }
      }
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final g = day.glucose;
    final readings = g?.window.readings ?? [];

    int tirPercent = 0;
    int lowPercent = 0;
    int highPercent = 0;
    int? meanGlucose;
    int? minGlucose;
    int? maxGlucose;
    int lowMinutes = 0;
    int highMinutes = 0;
    int inRangeMinutes = 0;

    if (g != null && g.window.observed > Duration.zero) {
      meanGlucose = g.mean?.round();
      final totalObs = g.window.observed.inMilliseconds;
      tirPercent = (g.window.inRange.inMilliseconds / totalObs * 100).round();
      lowPercent = (g.window.belowRange.inMilliseconds / totalObs * 100).round();
      highPercent =
          (g.window.aboveRange.inMilliseconds / totalObs * 100).round();
      lowMinutes = g.window.belowRange.inMinutes;
      highMinutes = g.window.aboveRange.inMinutes;
      inRangeMinutes = g.window.inRange.inMinutes;
      if (readings.isNotEmpty) {
        minGlucose = readings.map((r) => r.sgv).reduce(math.min);
        maxGlucose = readings.map((r) => r.sgv).reduce(math.max);
      }
    }

    final events = _getEvents();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Nagłówek karty z min-max / aktualną wartością
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.show_chart_rounded, size: 18, color: primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Przebieg glikemii (24h)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: numColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (minGlucose != null && maxGlucose != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Min: $minGlucose · Max: $maxGlucose mg/dl · Śr: ${meanGlucose ?? '—'}',
                          style: TextStyle(fontSize: 11, color: mutedColor),
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ),
              if (readings.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorForGlucose(readings.last.sgv.toDouble())
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _colorForGlucose(readings.last.sgv.toDouble())
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color:
                              _colorForGlucose(readings.last.sgv.toDouble()),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${readings.last.sgv} mg/dl',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _colorForGlucose(
                              readings.last.sgv.toDouble()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (widget.showStyleSelector) ...[
            const SizedBox(height: 12),
            // 2. Przełącznik stylu prezentacji wykresu
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  _buildStyleOption(
                    style: CaregiverChartStyle.eventPins,
                    label: '📍 Ze zdarzeniami',
                    isDark: isDark,
                    primary: primary,
                  ),
                  _buildStyleOption(
                    style: CaregiverChartStyle.smoothSpline,
                    label: '🌊 Płynna wstęga',
                    isDark: isDark,
                    primary: primary,
                  ),
                  _buildStyleOption(
                    style: CaregiverChartStyle.clinicalDots,
                    label: '🟢 Punkty CGM',
                    isDark: isDark,
                    primary: primary,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 3. Płótno wykresu (CustomPaint) z obsługą dotyku (scrubbing)
          GestureDetector(
            onPanDown: (d) => setState(() => _touchOffset = d.localPosition),
            onPanUpdate: (d) => setState(() => _touchOffset = d.localPosition),
            onPanEnd: (_) => setState(() => _touchOffset = null),
            onPanCancel: () => setState(() => _touchOffset = null),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: CaregiverDayGlucosePainter(
                  readings: readings,
                  events: events,
                  dayStart: DateTime(
                    day.start.year,
                    day.start.month,
                    day.start.day,
                    0,
                    0,
                  ),
                  asOf: day.asOf,
                  style: _style,
                  isDark: isDark,
                  touchOffset: _touchOffset,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Kompaktowy, zintegrowany pasek TIR (Target Range Breakdown)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (lowPercent > 0)
                    Expanded(
                      flex: math.max(1, lowPercent),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                  if (tirPercent > 0)
                    Expanded(
                      flex: math.max(1, tirPercent),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (highPercent > 0)
                    Expanded(
                      flex: math.max(1, highPercent),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 5. Legenda i czas w poszczególnych zakresach (odporna na overflow)
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFEF4444),
                  label: '<70: $lowPercent% (${lowMinutes}m)',
                  mutedColor: mutedColor,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFF10B981),
                  label: 'Norma: $tirPercent% (${(inRangeMinutes / 60).toStringAsFixed(1)}h)',
                  mutedColor: mutedColor,
                  alignment: Alignment.center,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFF59E0B),
                  label: '>180: $highPercent% (${(highMinutes / 60).toStringAsFixed(1)}h)',
                  mutedColor: mutedColor,
                  alignment: Alignment.centerRight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyleOption({
    required CaregiverChartStyle style,
    required String label,
    required bool isDark,
    required Color primary,
  }) {
    final isSelected = _style == style;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _style = style),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.white : primary)
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required Color mutedColor,
    Alignment alignment = Alignment.center,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorForGlucose(double value) {
  if (value < 70) {
    return const Color(0xFFEF4444);
  } else if (value <= 180) {
    return const Color(0xFF10B981);
  } else if (value <= 250) {
    return const Color(0xFFF59E0B);
  } else {
    return const Color(0xFFDC2626);
  }
}

class CaregiverDayGlucosePainter extends CustomPainter {
  final List<Glucose> readings;
  final List<CaregiverChartEvent> events;
  final DateTime dayStart;
  final DateTime asOf;
  final CaregiverChartStyle style;
  final bool isDark;
  final Offset? touchOffset;

  CaregiverDayGlucosePainter({
    required this.readings,
    required this.events,
    required this.dayStart,
    required this.asOf,
    required this.style,
    required this.isDark,
    this.touchOffset,
  });

  static const double lowThreshold = 70.0;
  static const double targetLine = 110.0;
  static const double highThreshold = 180.0;
  static const double veryHighThreshold = 250.0;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 6.0;
    const rightPad = 34.0; // Na etykiety Y: 70, 110, 180, 250
    final topPad = style == CaregiverChartStyle.eventPins ? 26.0 : 12.0;
    const bottomPad = 22.0; // Na godziny: 00:00, 04:00, ...

    final chartArea = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    final double minY = 40.0;
    final double maxY = math.max(
      270.0,
      readings.isEmpty
          ? 270.0
          : ((readings.map((r) => r.sgv).reduce(math.max) + 19) ~/ 20) * 20.0,
    );

    double xForTime(DateTime t) {
      final diffMin = t.difference(dayStart).inSeconds / 60.0;
      final ratio = (diffMin / 1440.0).clamp(0.0, 1.0);
      return chartArea.left + ratio * chartArea.width;
    }

    double yForSgv(double sgv) {
      final clamped = sgv.clamp(minY, maxY);
      final ratio = (clamped - minY) / (maxY - minY);
      return chartArea.bottom - ratio * chartArea.height;
    }

    // 1. TŁA PASM (Korytarz docelowy i strefy)
    final y180 = yForSgv(highThreshold);
    final y70 = yForSgv(lowThreshold);

    // Korytarz docelowy 70–180 mg/dl (szmaragdowy tint)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(chartArea.left, y180, chartArea.right, y70),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(0xFF10B981)
            .withValues(alpha: isDark ? 0.08 : 0.05),
    );

    // Strefa hipo < 70 mg/dl (czerwony delikatny tint)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(chartArea.left, y70, chartArea.right, chartArea.bottom),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(0xFFEF4444)
            .withValues(alpha: isDark ? 0.07 : 0.04),
    );

    // 2. LINIE REFERENCYJNE (70, 110, 180, 250)
    final gridLinePaint = Paint()
      ..color = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.6)
          : const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;

    // Linia 250
    final y250 = yForSgv(veryHighThreshold);
    canvas.drawLine(
      Offset(chartArea.left, y250),
      Offset(chartArea.right, y250),
      gridLinePaint,
    );

    // Linia przerywana 180
    drawDashedChartLine(
      canvas,
      Offset(chartArea.left, y180),
      Offset(chartArea.right, y180),
      Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.40)
        ..strokeWidth = 0.9,
    );

    // Subtelna linia celu 110
    final y110 = yForSgv(targetLine);
    drawDashedChartLine(
      canvas,
      Offset(chartArea.left, y110),
      Offset(chartArea.right, y110),
      Paint()
        ..color = isDark
            ? const Color(0xFF475569).withValues(alpha: 0.45)
            : const Color(0xFFCBD5E1)
        ..strokeWidth = 0.7,
    );

    // Linia przerywana 70
    drawDashedChartLine(
      canvas,
      Offset(chartArea.left, y70),
      Offset(chartArea.right, y70),
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.45)
        ..strokeWidth = 0.9,
    );

    // Etykiety Y po prawej stronie
    _drawText(
      canvas,
      '250',
      Offset(chartArea.right + 6, y250 - 5),
      TextStyle(
        fontSize: 9.5,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
    _drawText(
      canvas,
      '180',
      Offset(chartArea.right + 6, y180 - 5),
      const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF10B981),
      ),
    );
    _drawText(
      canvas,
      '110',
      Offset(chartArea.right + 6, y110 - 5),
      TextStyle(
        fontSize: 8.5,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
    );
    _drawText(
      canvas,
      '70',
      Offset(chartArea.right + 6, y70 - 5),
      const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFFEF4444),
      ),
    );

    // 3. OŚ CZASU X (00:00, 04:00, 08:00, 12:00, 16:00, 20:00, 24:00)
    for (int h = 0; h <= 24; h += 4) {
      final hourTime = dayStart.add(Duration(hours: h));
      final x = xForTime(hourTime);
      final label = h == 24 ? '24:00' : '${h.toString().padLeft(2, '0')}:00';

      // Prowadnica pionowa
      canvas.drawLine(
        Offset(x, chartArea.top),
        Offset(x, chartArea.bottom),
        Paint()
          ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
              .withValues(alpha: 0.5)
          ..strokeWidth = 0.6,
      );

      _drawText(
        canvas,
        label,
        Offset(x - 12, chartArea.bottom + 5),
        TextStyle(
          fontSize: 9.5,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      );
    }

    // 4. KRZYWA LUB PUNKTY GLIKEMII
    if (readings.isNotEmpty) {
      // Podział na ciągłe serie (gap > 15 min oznacza przerwę w CGM)
      final List<List<Glucose>> segments = [];
      List<Glucose> currentSegment = [readings.first];

      for (int i = 1; i < readings.length; i++) {
        final prev = readings[i - 1];
        final curr = readings[i];
        if (curr.date.difference(prev.date).inMinutes <= 15) {
          currentSegment.add(curr);
        } else {
          segments.add(currentSegment);
          currentSegment = [curr];
        }
      }
      segments.add(currentSegment);

      for (final seg in segments) {
        if (seg.isEmpty) continue;

        final points = seg
            .map((r) => Offset(xForTime(r.date), yForSgv(r.sgv.toDouble())))
            .toList();

        if (style == CaregiverChartStyle.smoothSpline ||
            style == CaregiverChartStyle.eventPins) {
          // Płynna krzywa Beziera
          final path = Path();
          path.moveTo(points.first.dx, points.first.dy);

          for (int i = 0; i < points.length - 1; i++) {
            final p0 = points[i];
            final p1 = points[i + 1];
            final midX = (p0.dx + p1.dx) / 2;
            path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
          }

          // Ambient Gradient pod wykresem
          final fillPath = Path.from(path);
          fillPath.lineTo(points.last.dx, chartArea.bottom);
          fillPath.lineTo(points.first.dx, chartArea.bottom);
          fillPath.close();

          final fillPaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF10B981)
                    .withValues(alpha: isDark ? 0.22 : 0.16),
                const Color(0xFF10B981).withValues(alpha: 0.0),
              ],
            ).createShader(chartArea);

          canvas.drawPath(fillPath, fillPaint);

          // Pociągnięcie linii wykresu
          final strokePaint = Paint()
            ..color = const Color(0xFF10B981)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          canvas.drawPath(path, strokePaint);
        }

        // Kropki CGM (zawsze w stylu clinicalDots lub subtelne w pozostałych)
        if (style == CaregiverChartStyle.clinicalDots) {
          for (final r in seg) {
            final pt = Offset(xForTime(r.date), yForSgv(r.sgv.toDouble()));
            final c = _colorForGlucose(r.sgv.toDouble());

            canvas.drawCircle(
              pt,
              3.0,
              Paint()..color = c,
            );
            canvas.drawCircle(
              pt,
              1.2,
              Paint()..color = Colors.white,
            );
          }
        }
      }

      // Ostatni punkt pomiarowy z pulsującym pierścieniem
      final lastReading = readings.last;
      final lastPt = Offset(
        xForTime(lastReading.date),
        yForSgv(lastReading.sgv.toDouble()),
      );
      final lastColor = _colorForGlucose(lastReading.sgv.toDouble());

      canvas.drawCircle(
        lastPt,
        6.5,
        Paint()
          ..color = lastColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        lastPt,
        4.0,
        Paint()
          ..color = lastColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        lastPt,
        1.8,
        Paint()..color = Colors.white,
      );
    }

    // 5. PINY ZDARZEŃ NA OSI (Gdy aktywny styl eventPins)
    if (style == CaregiverChartStyle.eventPins && events.isNotEmpty) {
      for (final event in events) {
        final evX = xForTime(event.time);
        if (evX < chartArea.left || evX > chartArea.right) continue;

        // Prowadnica pionowa od pinu do wykresu
        drawDashedChartLine(
          canvas,
          Offset(evX, chartArea.top - 4),
          Offset(evX, chartArea.bottom),
          Paint()
            ..color = event.color.withValues(alpha: 0.35)
            ..strokeWidth = 0.8,
        );

        // Znacznik pinu u góry
        final pinRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(evX, chartArea.top - 14),
            width: 44,
            height: 18,
          ),
          const Radius.circular(9),
        );

        canvas.drawRRect(
          pinRect,
          Paint()
            ..color = event.color
            ..style = PaintingStyle.fill,
        );

        _drawText(
          canvas,
          event.detail,
          Offset(evX - 18, chartArea.top - 20),
          const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        );
      }
    }

    // 6. OBSŁUGA DOTYKU (SCRUBBING & TOOLTIP)
    if (touchOffset != null && readings.isNotEmpty) {
      final touchX = touchOffset!.dx.clamp(chartArea.left, chartArea.right);

      // Znajdź najbliższy odczyt do palca
      Glucose? nearestReading;
      double minDistance = double.infinity;

      for (final r in readings) {
        final ptX = xForTime(r.date);
        final dist = (ptX - touchX).abs();
        if (dist < minDistance) {
          minDistance = dist;
          nearestReading = r;
        }
      }

      if (nearestReading != null) {
        final rX = xForTime(nearestReading.date);
        final rY = yForSgv(nearestReading.sgv.toDouble());
        final rColor = _colorForGlucose(nearestReading.sgv.toDouble());

        // Pionowa linia wskaźnika
        canvas.drawLine(
          Offset(rX, chartArea.top),
          Offset(rX, chartArea.bottom),
          Paint()
            ..color = isDark ? Colors.white : Colors.black
            ..strokeWidth = 1.2,
        );

        // Podświetlony punkt
        canvas.drawCircle(
          Offset(rX, rY),
          7.0,
          Paint()..color = rColor.withValues(alpha: 0.3),
        );
        canvas.drawCircle(
          Offset(rX, rY),
          4.5,
          Paint()..color = rColor,
        );
        canvas.drawCircle(
          Offset(rX, rY),
          2.0,
          Paint()..color = Colors.white,
        );

        // Dymek tooltipa
        final timeStr =
            '${nearestReading.date.hour.toString().padLeft(2, '0')}:${nearestReading.date.minute.toString().padLeft(2, '0')}';
        final text = '$timeStr · ${nearestReading.sgv} mg/dl';

        final tooltipWidth = 110.0;
        final tooltipHeight = 24.0;
        final tooltipX = (rX - tooltipWidth / 2)
            .clamp(chartArea.left, chartArea.right - tooltipWidth);
        final tooltipY = math.max(chartArea.top + 2, rY - 32);

        final tooltipRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
          const Radius.circular(6),
        );

        canvas.drawRRect(
          tooltipRRect,
          Paint()
            ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B)
            ..style = PaintingStyle.fill,
        );

        // Kolorowa kropka w tooltipie
        canvas.drawCircle(
          Offset(tooltipX + 12, tooltipY + 12),
          3.5,
          Paint()..color = rColor,
        );

        _drawText(
          canvas,
          text,
          Offset(tooltipX + 20, tooltipY + 5),
          const TextStyle(
            fontSize: 10,
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
  bool shouldRepaint(covariant CaregiverDayGlucosePainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.events != events ||
        oldDelegate.dayStart != dayStart ||
        oldDelegate.asOf != asOf ||
        oldDelegate.style != style ||
        oldDelegate.isDark != isDark ||
        oldDelegate.touchOffset != touchOffset;
  }
}
