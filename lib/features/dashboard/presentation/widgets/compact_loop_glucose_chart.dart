import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/charts/draw_dashed_chart_line.dart';
import '../../../../common/presentation/charts/glucose_chart_timeline.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../data/providers/blood_sugar_readings_list_provider.dart';

/// Kliniczna skala glikemii Loop:
/// Dolna granica to 70 mg/dl (próg normy / hipoglikemii),
/// Górna granica to co najmniej 180 mg/dl.
class ClinicalGlucoseScale {
  final int minimum;
  final int middle;
  final int maximum;

  const ClinicalGlucoseScale({
    required this.minimum,
    required this.middle,
    required this.maximum,
  });

  factory ClinicalGlucoseScale.fromValues(Iterable<int> values) {
    final rawMin = values.isEmpty ? 100 : values.reduce(math.min);
    final rawMax = values.isEmpty ? 140 : values.reduce(math.max);

    var minTick = 70;
    if (rawMin < 70) {
      minTick = math.max(40, (rawMin / 10).floor() * 10);
    }

    var maxTick = 180;
    if (rawMax > 180) {
      maxTick = ((rawMax + 10) / 20).ceil() * 20;
    }

    final midTick = ((minTick + maxTick) / 2).round();

    return ClinicalGlucoseScale(
      minimum: minTick,
      middle: midTick,
      maximum: maxTick,
    );
  }
}

/// Wykres glikemii z predykcją w stylu iOS Loop:
/// - Lewa część: rzeczywista historia odczytów z subtelnym gradientem
/// - Pionowy separator: wskaźnik "Teraz" z podświetlonym pierścieniem
/// - Prawa część: prognoza spadku/stabilizacji cukru (predykcja pętli Loop)
/// - Dolna oś czasu: -2h, -1h, [ Teraz ], +1h, +2h
class CompactLoopGlucoseChart extends ConsumerWidget {
  final double height;
  final bool isDark;
  final List<Glucose>? readings;

  const CompactLoopGlucoseChart({
    super.key,
    this.height = 120,
    this.isDark = false,
    this.readings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = readings != null
        ? AsyncData<List<Glucose>>(readings!)
        : ref.watch(bloodSugarReadingsListProvider);
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return readingsAsync.when(
      data: (readingsList) {
        if (readingsList.length < 3) {
          return SizedBox(
            height: height,
            child: Center(
              child: Text(
                'Oczekiwanie na historię odczytów...',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ),
          );
        }

        final timeline = GlucoseChartTimeline(
          readingsList.reversed.toList(),
          maxReadings: 12,
        );
        final data = timeline.values;
        final scale =
            ClinicalGlucoseScale.fromValues(data.map((value) => value.sgv));

        return SizedBox(
          height: height,
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _LoopPredictionChartPainter(
                    timeline: timeline,
                    scale: scale,
                    isDark: dark,
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 4),
              // Dolna oś czasu: przeszłość (lewa) -> TERAZ -> przyszłość (prawa)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('-2h',
                        style: TextStyle(fontSize: 9, color: mutedColor)),
                    Text('-1h',
                        style: TextStyle(fontSize: 9, color: mutedColor)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A3FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(context.lang.glucoseChartNow,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00A3FF))),
                    ),
                    Text('+1h',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: mutedColor)),
                    Text('+2h',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: mutedColor)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => SizedBox(
        height: height,
        child: const Center(
          child: Text('Błąd odczytu danych', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _LoopPredictionChartPainter extends CustomPainter {
  final GlucoseChartTimeline timeline;
  final ClinicalGlucoseScale scale;
  final bool isDark;

  _LoopPredictionChartPainter({
    required this.timeline,
    required this.scale,
    required this.isDark,
  });

  static const lowThreshold = 70.0;
  static const highThreshold = 180.0;
  static const veryHighThreshold = 250.0;

  static Color colorForGlucose(double value) {
    if (value < lowThreshold) {
      return const Color(0xFFEF4444); // Czerwony poniżej 70
    } else if (value <= highThreshold) {
      return const Color(0xFF10B981); // Zielony 70-180
    } else if (value <= veryHighThreshold) {
      return const Color(0xFFF59E0B); // Żółty / bursztynowy 180-250
    } else {
      return const Color(0xFFDC2626); // Czerwony powyżej 250
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final data = timeline.values;
    if (data.length < 3) return;

    final minY = scale.minimum.toDouble();
    final maxY = scale.maximum.toDouble();

    const topPad = 6.0;
    const bottomPad = 6.0;
    final h = size.height - topPad - bottomPad;
    final w = size.width;

    double yFor(double val) {
      final v = val.clamp(minY, maxY).toDouble();
      final t = (v - minY) / (maxY - minY);
      return topPad + (1.0 - t) * h;
    }

    double valForY(double y) {
      if (h <= 0) return minY;
      final t = (1.0 - ((y - topPad) / h)).clamp(0.0, 1.0);
      return minY + t * (maxY - minY);
    }

    // 1. Pasmo docelowe (70–180 mg/dl)
    if (maxY > lowThreshold && minY < highThreshold) {
      final yLow = yFor(lowThreshold);
      final yHigh = yFor(math.min(highThreshold, maxY));
      final bandTop = math.min(yLow, yHigh);
      final bandBottom = math.max(yLow, yHigh);
      if (bandBottom > bandTop) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(0, bandTop, w, bandBottom),
            const Radius.circular(4),
          ),
          Paint()
            ..color = const Color(0xFF10B981)
                .withValues(alpha: isDark ? 0.08 : 0.06),
        );
        drawDashedChartLine(
          canvas,
          Offset(0, bandTop),
          Offset(w, bandTop),
          Paint()
            ..color = const Color(0xFF10B981)
                .withValues(alpha: isDark ? 0.35 : 0.30)
            ..strokeWidth = 0.8,
        );
        drawDashedChartLine(
          canvas,
          Offset(0, bandBottom),
          Offset(w, bandBottom),
          Paint()
            ..color = const Color(0xFF10B981)
                .withValues(alpha: isDark ? 0.35 : 0.30)
            ..strokeWidth = 0.8,
        );

        // Etykiety osi na liniach
        _drawLabel(canvas, '180', Offset(2, bandTop - 10), isDark);
        _drawLabel(canvas, '70', Offset(2, bandBottom - 10), isDark);
      }
    }

    // Podział na przeszłość (0..0.55) i predykcję (0.55..1.0)
    final xNow = w * 0.55;

    // Obliczenie punktów przeszłości
    final pastPoints = <Offset>[];
    for (final reading in data) {
      final frac = timeline.fractionAt(reading.date); // 0..1
      final x = frac * xNow;
      final y = yFor(reading.sgv.toDouble());
      pastPoints.add(Offset(x, y));
    }

    final latestReading = data.last;
    final yNow = yFor(latestReading.sgv.toDouble());
    final latestColor = colorForGlucose(latestReading.sgv.toDouble());

    // 2. Pionowa linia "Teraz" w kolorze bieżącego odczytu
    drawDashedChartLine(
      canvas,
      Offset(xNow, topPad),
      Offset(xNow, topPad + h),
      Paint()
        ..color = latestColor.withValues(alpha: 0.40)
        ..strokeWidth = 1.0,
    );

    // 3. Rysowanie linii przeszłości z dynamicznymi kolorami (norma zielona, >180 żółta, >250/<70 czerwona)
    if (pastPoints.isNotEmpty) {
      final pastPath = Path()..moveTo(pastPoints.first.dx, pastPoints.first.dy);
      for (var i = 1; i < pastPoints.length; i++) {
        final p0 = pastPoints[i - 1];
        final p1 = pastPoints[i];
        final midX = (p0.dx + p1.dx) / 2;
        pastPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);

        final c0 = colorForGlucose(data[i - 1].sgv.toDouble());
        final c1 = colorForGlucose(data[i].sgv.toDouble());

        final segPath = Path()
          ..moveTo(p0.dx, p0.dy)
          ..cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);

        final segPaint = Paint()
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        if (c0 == c1) {
          segPaint.color = c1;
        } else {
          segPaint.shader = LinearGradient(
            colors: [c0, c1],
          ).createShader(Rect.fromPoints(p0, p1));
        }

        canvas.drawPath(segPath, segPaint);
      }

      // Gradient pod przeszłością w odcieniu bieżącego odczytu
      final fillPath = Path.from(pastPath)
        ..lineTo(xNow, topPad + h)
        ..lineTo(0, topPad + h)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              latestColor.withValues(alpha: isDark ? 0.22 : 0.12),
              latestColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTRB(0, topPad, xNow, topPad + h)),
      );

      // Punkt TERAZ (pulsujący pierścień w kolorze bieżącego odczytu)
      canvas.drawCircle(
        Offset(xNow, yNow),
        5.5,
        Paint()..color = latestColor,
      );
      canvas.drawCircle(
        Offset(xNow, yNow),
        2.5,
        Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white,
      );
    }

    // 4. PREDYKCJA LOOP (Przyszłość: xNow .. w)
    // Cel predykcji: łagodne dążenie do strefy normy (110–115 mg/dl)
    final targetVal = latestReading.sgv > 180
        ? 110.0
        : (latestReading.sgv < 70 ? 105.0 : 110.0);
    final yTarget = yFor(targetVal);

    // Gładka krzywa predykcji od punktu TERAZ do celu za 2h
    final predPath = Path()..moveTo(xNow, yNow);
    final dx = w - xNow;
    final dy = yTarget - yNow;
    // c1: łagodne rozpoczęcie z uwzględnieniem inercji (początkowy spadek/wzrost 12%)
    final c1 = Offset(xNow + dx * 0.38, yNow + dy * 0.12);
    // c2: płynne wypłaszczenie w kierunku poziomu docelowego
    final c2 = Offset(xNow + dx * 0.72, yTarget + (yNow - yTarget) * 0.05);
    predPath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, w, yTarget);

    // Rysowanie przerywanej linii predykcji – każda kreska przyjmuje kolor
    // odpowiadający prognozowanemu poziomowi cukru w danym punkcie czasu:
    // > 250: czerwony, > 180: żółty, 70-180: zielony, < 70: czerwony.
    // Dzięki przerywanej linii prognoza jest natychmiast odróżnialna od linii ciągłej.
    const dashLength = 3.5;
    const gapLength = 4.5;
    for (final metric in predPath.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final endDistance = math.min(distance + dashLength, metric.length);
        final midDistance = (distance + endDistance) / 2;
        final tangent = metric.getTangentForOffset(midDistance);
        if (tangent != null) {
          final glucoseAtDash = valForY(tangent.position.dy);
          final dashColor = colorForGlucose(glucoseAtDash);
          final dashPath = metric.extractPath(distance, endDistance);
          canvas.drawPath(
            dashPath,
            Paint()
              ..color = dashColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeCap = StrokeCap.round,
          );
        }
        distance += dashLength + gapLength;
      }
    }

    // Punkt docelowy prognozy w kolorze docelowym (zielony dla 110)
    final targetColor = colorForGlucose(targetVal);
    canvas.drawCircle(
      Offset(w, yTarget),
      4.5,
      Paint()..color = targetColor,
    );
    canvas.drawCircle(
      Offset(w, yTarget),
      2.0,
      Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, bool isDark) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LoopPredictionChartPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
