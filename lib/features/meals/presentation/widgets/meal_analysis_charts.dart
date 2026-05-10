import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/model/glucose.dart';
import '../../data/models/meal_analysis_data.dart';

class MealGlucoseChart extends StatelessWidget {
  final MealAnalysisData analysis;

  const MealGlucoseChart({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis.glucoseReadings.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Brak odczytów glikemii w tym okresie')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final bounds = MealChartBounds.fromGlucose(analysis);

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: bounds.totalMinutes,
          minY: bounds.minY,
          maxY: bounds.maxY,
          clipData: const FlClipData.all(),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(
                y1: bounds.minY,
                y2: 70,
                color: Colors.red.withValues(alpha: 0.08),
              ),
              HorizontalRangeAnnotation(
                y1: 70,
                y2: 180,
                color: Colors.green.withValues(alpha: 0.08),
              ),
              HorizontalRangeAnnotation(
                y1: 180,
                y2: 250,
                color: Colors.amber.withValues(alpha: 0.10),
              ),
              HorizontalRangeAnnotation(
                y1: 250,
                y2: bounds.maxY,
                color: Colors.red.withValues(alpha: 0.08),
              ),
            ],
            verticalRangeAnnotations: [
              VerticalRangeAnnotation(
                x1: bounds.minutesFromStart(analysis.mealTime),
                x2: bounds.minutesFromStart(analysis.mealTime),
                color: scheme.primary.withValues(alpha: 0.25),
              ),
            ],
          ),
          lineBarsData: [
            ..._glucoseSegments(bounds),
            ..._eventMarkers(bounds, analysis),
          ],
          titlesData: _titles(context, analysis, bounds),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (value) {
              final isThreshold = value == 70 || value == 180 || value == 250;
              return FlLine(
                color: isThreshold
                    ? scheme.outline.withValues(alpha: 0.45)
                    : scheme.outlineVariant.withValues(alpha: 0.45),
                strokeWidth: isThreshold ? 1.2 : 0.8,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final time = analysis.chartStart.add(
                    Duration(minutes: spot.x.round()),
                  );
                  return LineTooltipItem(
                    '${_formatTime(time)}\n${spot.y.round()} mg/dL',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  List<LineChartBarData> _glucoseSegments(MealChartBounds bounds) {
    final readings = analysis.glucoseReadings;
    if (readings.length == 1) {
      final glucose = readings.first;
      return [
        LineChartBarData(
          spots: [
            FlSpot(
              bounds.minutesFromStart(glucose.date),
              glucose.sgv.toDouble(),
            ),
          ],
          color: _glucoseColor(glucose.sgv.toDouble()),
          barWidth: 0,
          dotData: const FlDotData(show: true),
        ),
      ];
    }

    final segments = <LineChartBarData>[];
    for (var i = 0; i < readings.length - 1; i++) {
      segments.addAll(_splitSegment(bounds, readings[i], readings[i + 1]));
    }
    return segments;
  }

  List<LineChartBarData> _splitSegment(
    MealChartBounds bounds,
    Glucose start,
    Glucose end,
  ) {
    final startValue = start.sgv.toDouble();
    final endValue = end.sgv.toDouble();
    final delta = endValue - startValue;
    final splitPoints = <double>{0, 1};

    if (delta != 0) {
      for (final threshold in [70.0, 180.0, 250.0]) {
        final t = (threshold - startValue) / delta;
        if (t > 0 && t < 1) splitPoints.add(t);
      }
    }

    final sorted = splitPoints.toList()..sort();
    final bars = <LineChartBarData>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      final midValue = startValue + delta * ((a + b) / 2);
      bars.add(
        LineChartBarData(
          spots: [
            _spotAt(bounds, start, end, a),
            _spotAt(bounds, start, end, b),
          ],
          color: _glucoseColor(midValue),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    return bars;
  }

  FlSpot _spotAt(MealChartBounds bounds, Glucose start, Glucose end, double t) {
    final startMs = start.date.millisecondsSinceEpoch;
    final endMs = end.date.millisecondsSinceEpoch;
    final millis = startMs + ((endMs - startMs) * t).round();
    final value = start.sgv + (end.sgv - start.sgv) * t;
    return FlSpot(
      bounds.minutesFromStart(DateTime.fromMillisecondsSinceEpoch(millis)),
      value.toDouble(),
    );
  }

  List<LineChartBarData> _eventMarkers(
    MealChartBounds bounds,
    MealAnalysisData analysis,
  ) {
    final markerY = bounds.maxY - 8;
    return analysis.timelineEvents.map((event) {
      return LineChartBarData(
        spots: [FlSpot(bounds.minutesFromStart(event.timestamp), markerY)],
        color: _eventColor(event.type),
        barWidth: 0,
        dotData: FlDotData(
          getDotPainter: (spot, percent, bar, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: _eventColor(event.type),
              strokeColor: Colors.white,
              strokeWidth: 1,
            );
          },
        ),
      );
    }).toList();
  }

  FlTitlesData _titles(
    BuildContext context,
    MealAnalysisData analysis,
    MealChartBounds bounds,
  ) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          interval: 50,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              meta: meta,
              child: Text(
                value.round().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: math.max(30, bounds.totalMinutes / 4).toDouble(),
          getTitlesWidget: (value, meta) {
            final time = analysis.chartStart.add(
              Duration(minutes: value.round()),
            );
            return SideTitleWidget(
              meta: meta,
              child: Text(
                _formatTime(time),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
    );
  }
}

class MealCobIobChart extends StatelessWidget {
  final MealAnalysisData analysis;

  const MealCobIobChart({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis.deviceStatuses.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Brak COB / IOB w tym okresie')),
      );
    }

    final bounds = MealChartBounds.fromDeviceStatuses(analysis);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 230,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: bounds.totalMinutes,
          minY: 0,
          maxY: bounds.maxY,
          clipData: const FlClipData.all(),
          lineBarsData: [
            LineChartBarData(
              spots: analysis.deviceStatuses
                  .map(
                    (status) => FlSpot(
                      bounds.minutesFromStart(status.date),
                      status.cob,
                    ),
                  )
                  .toList(),
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: analysis.deviceStatuses
                  .map(
                    (status) => FlSpot(
                      bounds.minutesFromStart(status.date),
                      status.iob,
                    ),
                  )
                  .toList(),
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
          titlesData: _simpleTitles(context, analysis, bounds),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) {
              return FlLine(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
                strokeWidth: 0.8,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  FlTitlesData _simpleTitles(
    BuildContext context,
    MealAnalysisData analysis,
    MealChartBounds bounds,
  ) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              meta: meta,
              child: Text(
                value.round().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: math.max(30, bounds.totalMinutes / 4).toDouble(),
          getTitlesWidget: (value, meta) {
            final time = analysis.chartStart.add(
              Duration(minutes: value.round()),
            );
            return SideTitleWidget(
              meta: meta,
              child: Text(
                _formatTime(time),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
    );
  }
}

class MealChartBounds {
  final DateTime start;
  final DateTime end;
  final double minY;
  final double maxY;
  final double totalMinutes;

  const MealChartBounds({
    required this.start,
    required this.end,
    required this.minY,
    required this.maxY,
    required this.totalMinutes,
  });

  factory MealChartBounds.fromGlucose(MealAnalysisData analysis) {
    final values = analysis.glucoseReadings.map((g) => g.sgv).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    return MealChartBounds(
      start: analysis.chartStart,
      end: analysis.chartEnd,
      minY: math.min(60, minValue - 12).toDouble(),
      maxY: math.max(260, maxValue + 12).toDouble(),
      totalMinutes: _totalMinutes(analysis),
    );
  }

  factory MealChartBounds.fromDeviceStatuses(MealAnalysisData analysis) {
    final maxCob = analysis.deviceStatuses
        .map((status) => status.cob)
        .fold<double>(0, math.max);
    final maxIob = analysis.deviceStatuses
        .map((status) => status.iob)
        .fold<double>(0, math.max);
    return MealChartBounds(
      start: analysis.chartStart,
      end: analysis.chartEnd,
      minY: 0,
      maxY: math.max(10, math.max(maxCob, maxIob) + 2),
      totalMinutes: _totalMinutes(analysis),
    );
  }

  double minutesFromStart(DateTime date) {
    final minutes = date.difference(start).inMinutes.toDouble();
    return minutes.clamp(0, totalMinutes).toDouble();
  }

  static double _totalMinutes(MealAnalysisData analysis) {
    return math.max(
      1,
      analysis.chartEnd.difference(analysis.chartStart).inMinutes.toDouble(),
    );
  }
}

Color _glucoseColor(double value) {
  if (value < 70 || value > 250) return Colors.red;
  if (value > 180) return Colors.amber.shade700;
  return Colors.green;
}

Color _eventColor(MealTimelineEventType type) {
  return switch (type) {
    MealTimelineEventType.insulin => Colors.blue,
    MealTimelineEventType.carbs => Colors.green,
    MealTimelineEventType.correction => Colors.deepPurple,
    MealTimelineEventType.activity => Colors.teal,
    MealTimelineEventType.mealStatus => Colors.orange,
    MealTimelineEventType.meal => Colors.brown,
    MealTimelineEventType.deviceStatus => Colors.grey,
  };
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
