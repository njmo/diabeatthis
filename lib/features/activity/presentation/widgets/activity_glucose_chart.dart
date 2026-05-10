import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/model/glucose.dart';
import '../../data/models/activity_log_analysis_data.dart';

class ActivityGlucoseChart extends StatelessWidget {
  final ActivityLogAnalysisData analysis;

  const ActivityGlucoseChart({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis.glucoseReadings.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Brak odczytów glikemii w tym okresie')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final bounds = _ChartBounds.from(analysis);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
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
                    x1: bounds.minutesFromStart(analysis.activityStart),
                    x2: bounds.minutesFromStart(analysis.activityEnd),
                    color: Colors.teal.withValues(alpha: 0.10),
                  ),
                  ...analysis.activityTargets.map((target) {
                    final targetEnd = target.createdAt.add(
                      Duration(minutes: target.duration),
                    );
                    return VerticalRangeAnnotation(
                      x1: bounds.minutesFromStart(
                        _maxDate(target.createdAt, analysis.chartStart),
                      ),
                      x2: bounds.minutesFromStart(
                        _minDate(targetEnd, analysis.chartEnd),
                      ),
                      color: Colors.blue.withValues(alpha: 0.12),
                    );
                  }),
                ],
              ),
              lineBarsData: [
                ..._glucoseSegments(bounds),
                ..._treatmentMarkers(bounds),
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
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
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 50,
                getDrawingHorizontalLine: (value) {
                  final isThreshold =
                      value == 70 || value == 180 || value == 250;
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
                getTouchedSpotIndicator: (barData, indicators) {
                  return indicators.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: scheme.outline.withValues(alpha: 0.35),
                        strokeWidth: 1,
                      ),
                      FlDotData(
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: bar.color ?? scheme.primary,
                            strokeColor: scheme.surface,
                            strokeWidth: 1,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final time = analysis.chartStart.add(
                        Duration(minutes: spot.x.round()),
                      );
                      return LineTooltipItem(
                        '${_formatTime(time)}\n${spot.y.round()} mg/dl',
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
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendItem(color: Colors.green, label: '70-180'),
            _LegendItem(color: Colors.amber, label: '180-250'),
            _LegendItem(color: Colors.red, label: '<70 / >250'),
            _LegendItem(color: Colors.blue, label: 'Activity target'),
            _LegendItem(color: Colors.teal, label: 'Aktywność'),
          ],
        ),
      ],
    );
  }

  List<LineChartBarData> _glucoseSegments(_ChartBounds bounds) {
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
    _ChartBounds bounds,
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

  List<LineChartBarData> _treatmentMarkers(_ChartBounds bounds) {
    final markerY = bounds.maxY - 8;
    return analysis.chartTreatments.map((treatment) {
      final createdAt = treatment.createdAt ?? analysis.chartStart;
      return LineChartBarData(
        spots: [FlSpot(bounds.minutesFromStart(createdAt), markerY)],
        color: treatment.getColor(),
        barWidth: 0,
        dotData: FlDotData(
          getDotPainter: (spot, percent, bar, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: treatment.getColor(),
              strokeColor: Colors.white,
              strokeWidth: 1,
            );
          },
        ),
      );
    }).toList();
  }

  FlSpot _spotAt(_ChartBounds bounds, dynamic start, dynamic end, double t) {
    final startMs = start.date.millisecondsSinceEpoch;
    final endMs = end.date.millisecondsSinceEpoch;
    final millis = startMs + ((endMs - startMs) * t).round();
    final value = start.sgv + (end.sgv - start.sgv) * t;
    return FlSpot(
      bounds.minutesFromStart(DateTime.fromMillisecondsSinceEpoch(millis)),
      value.toDouble(),
    );
  }

  Color _glucoseColor(double value) {
    if (value < 70 || value > 250) return Colors.red;
    if (value > 180) return Colors.amber.shade700;
    return Colors.green;
  }
}

class _ChartBounds {
  final ActivityLogAnalysisData analysis;
  final double minY;
  final double maxY;
  final double totalMinutes;

  const _ChartBounds({
    required this.analysis,
    required this.minY,
    required this.maxY,
    required this.totalMinutes,
  });

  factory _ChartBounds.from(ActivityLogAnalysisData analysis) {
    final values = analysis.glucoseReadings.map((g) => g.sgv).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final totalMinutes = analysis.chartEnd
        .difference(analysis.chartStart)
        .inMinutes
        .toDouble();

    return _ChartBounds(
      analysis: analysis,
      minY: math.min(60, minValue - 12).toDouble(),
      maxY: math.max(260, maxValue + 12).toDouble(),
      totalMinutes: math.max(1, totalMinutes),
    );
  }

  double minutesFromStart(DateTime date) {
    final minutes = date.difference(analysis.chartStart).inMinutes.toDouble();
    return minutes.clamp(0, totalMinutes).toDouble();
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
