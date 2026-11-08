import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/charts/draw_dashed_chart_line.dart';
import '../../../../common/presentation/charts/glucose_chart_timeline.dart';
import '../../../../common/widgets/waiting_for_data.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../data/providers/blood_sugar_readings_list_provider.dart';
import 'glucose_chart_scale.dart';

class MiniGlucoseChart extends ConsumerWidget {
  const MiniGlucoseChart({super.key, this.readings});
  final List<Glucose>? readings;
  static const axisWidth = 30.0;
  static const axisGap = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glucose = readings == null
        ? ref.watch(bloodSugarReadingsListProvider)
        : AsyncData<List<Glucose>>(readings!);

    return glucose.when(
      data: (glucose) {
        if (glucose.length < 3) {
          return WaitingForData(
            message: context.lang.dashboardWaitingForHistory,
          );
        }

        final painter = MiniGlucoseChartPainter(
          glucose.reversed.toList(),
          gridColor: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
        );
        final visible = painter._normalizedValues(painter.values);
        final scale = GlucoseChartScale.fromValues(
          visible.map((value) => value.sgv),
        );
        final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.lang.dashboardGlucoseUnit, style: labelStyle),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: axisWidth,
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final tick in [
                              (scale.maximum, 0.18),
                              (scale.middle, 0.5),
                              (scale.minimum, 0.82),
                            ])
                              Positioned(
                                top: constraints.maxHeight * tick.$2,
                                right: 0,
                                child: FractionalTranslation(
                                  translation: const Offset(0, -0.5),
                                  child: Text('${tick.$1}', style: labelStyle),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: axisGap),
                    Expanded(
                      child: CustomPaint(painter: painter, size: Size.infinite),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          WaitingForData(message: context.lang.dashboardWaitingForHistory),
      error: (error, _) => Text(context.lang.activityError(error)),
    );
  }
}

class MiniGlucoseChartPainter extends CustomPainter {
  static const maxReadings = 10;
  static const lowThreshold = 70.0;
  static const highThreshold = 180.0;
  static const veryHighThreshold = 250.0;
  static const lowColor = Color(0xFFE53935);
  static const targetColor = Color(0xFF43A047);
  static const highColor = Color(0xFFFBC02D);

  final List<Glucose> values;
  final Color? gridColor;

  MiniGlucoseChartPainter(this.values, {this.gridColor});

  Color _colorFor(double value) {
    if (value < lowThreshold || value >= veryHighThreshold) return lowColor;
    if (value >= highThreshold) return highColor;
    return targetColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final timeline = GlucoseChartTimeline(values, maxReadings: maxReadings);
    final data = timeline.values;
    if (data.length < 3) return;

    final scale = GlucoseChartScale.fromValues(data.map((value) => value.sgv));
    final minY = scale.minimum.toDouble();
    final maxY = scale.maximum.toDouble();

    final topPad = size.height * 0.18;
    final bottomPad = size.height * 0.18;
    final h = size.height - topPad - bottomPad;
    final w = size.width;

    if (gridColor != null) {
      final gridPaint = Paint()
        ..color = gridColor!
        ..strokeWidth = 0.6;
      for (final fraction in [0.0, 0.5, 1.0]) {
        final y = topPad + h * fraction;
        canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      }
    }

    Offset pointFor(double x, double value) {
      final v = value.clamp(minY, maxY).toDouble();
      final t = (v - minY) / (maxY - minY); // 0..1
      final y = topPad + (1.0 - t) * h;
      return Offset(x, y);
    }

    Paint segPaint(Color c) => Paint()
      ..color = c
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (var i = 1; i < timeline.segments.length; i++) {
      final before = timeline.segments[i - 1].last;
      final after = timeline.segments[i].first;
      drawDashedChartLine(
        canvas,
        pointFor(timeline.fractionAt(before.date) * w, before.sgv.toDouble()),
        pointFor(timeline.fractionAt(after.date) * w, after.sgv.toDouble()),
        Paint()
          ..color = (gridColor ?? const Color(0xFF90A4AE)).withValues(alpha: .5)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final segment in timeline.segments) {
      if (segment.length == 1) {
        final reading = segment.single;
        canvas.drawCircle(
          pointFor(
            timeline.fractionAt(reading.date) * w,
            reading.sgv.toDouble(),
          ),
          2,
          Paint()..color = _colorFor(reading.sgv.toDouble()),
        );
        continue;
      }
      for (var i = 0; i < segment.length - 1; i++) {
        final start = segment[i].sgv.toDouble();
        final end = segment[i + 1].sgv.toDouble();
        final startX = timeline.fractionAt(segment[i].date) * w;
        final endX = timeline.fractionAt(segment[i + 1].date) * w;
        final dx = endX - startX;
        final steps = math.max(8, (dx / 4).ceil());
        final splitPoints = <double>{
          for (var step = 0; step <= steps; step++) step / steps,
        }.toList()..sort();
        final samples = <MiniGlucoseChartSample>[];
        for (final t in splitPoints) {
          final smoothValue = _smoothValueAt(
            segment,
            i,
            t,
          ).clamp(math.min(start, end), math.max(start, end)).toDouble();
          samples.add(
            MiniGlucoseChartSample(
              pointFor(startX + dx * t, smoothValue),
              smoothValue,
            ),
          );
        }
        for (var j = 0; j < samples.length - 1; j++) {
          final first = samples[j];
          final last = samples[j + 1];
          final cuts = [0.0, ..._thresholdSplits(first.value, last.value), 1.0]
            ..sort();
          for (var k = 0; k < cuts.length - 1; k++) {
            final from = cuts[k];
            final to = cuts[k + 1];
            final midpoint =
                first.value + (last.value - first.value) * ((from + to) / 2);
            canvas.drawLine(
              Offset.lerp(first.offset, last.offset, from)!,
              Offset.lerp(first.offset, last.offset, to)!,
              segPaint(_colorFor(midpoint)),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MiniGlucoseChartPainter oldDelegate) {
    if (oldDelegate.gridColor != gridColor) return true;
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }

  List<Glucose> _normalizedValues(List<Glucose> values) {
    return GlucoseChartTimeline(values, maxReadings: maxReadings).values;
  }

  List<double> _thresholdSplits(double start, double end) {
    final delta = end - start;
    if (delta == 0) return const [];

    return [
      lowThreshold,
      highThreshold,
      veryHighThreshold,
    ].map((threshold) => (threshold - start) / delta).where((t) {
      return t > 0 && t < 1;
    }).toList();
  }

  double _smoothValueAt(List<Glucose> data, int index, double t) {
    final p0 = data[math.max(0, index - 1)].sgv.toDouble();
    final p1 = data[index].sgv.toDouble();
    final p2 = data[index + 1].sgv.toDouble();
    final p3 = data[math.min(data.length - 1, index + 2)].sgv.toDouble();
    final t2 = t * t;
    final t3 = t2 * t;

    return 0.5 *
        ((2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }
}

class MiniGlucoseChartSample {
  final Offset offset;
  final double value;

  const MiniGlucoseChartSample(this.offset, this.value);
}
