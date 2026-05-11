import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../data/models/meal_analysis_data.dart';

class MealGlucoseChart extends StatelessWidget {
  final MealAnalysisData analysis;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime>? onTimestampSelected;

  const MealGlucoseChart({
    super.key,
    required this.analysis,
    this.selectedTimestamp,
    this.onTimestampSelected,
  });

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
          extraLinesData: _extraLines(bounds, selectedTimestamp),
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
            touchCallback: (event, response) {
              final spot = response?.lineBarSpots?.firstOrNull;
              if (spot == null || !event.isInterestedForInteractions) {
                return;
              }
              onTimestampSelected?.call(
                analysis.chartStart.add(Duration(minutes: spot.x.round())),
              );
            },
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 220,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              tooltipMargin: 8,
              getTooltipItems: (spots) {
                if (spots.isEmpty) {
                  return const [];
                }
                final tooltip = _tooltipItemForSpots(
                  spots: spots,
                  analysis: analysis,
                  bounds: bounds,
                  textStyle: TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
                return [tooltip, for (var i = 1; i < spots.length; i++) null];
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
    final markers = _stackedEventMarkers(bounds, analysis);
    return markers.map((marker) {
      return LineChartBarData(
        spots: [FlSpot(marker.x, marker.y)],
        color: _eventColor(marker.event.type),
        barWidth: 0,
        dotData: FlDotData(
          getDotPainter: (spot, percent, bar, index) {
            return _TimelineEventIconPainter(
              icon: _eventIcon(marker.event.type),
              color: _eventColor(marker.event.type),
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
          interval: math.max(15, bounds.totalMinutes / 4).toDouble(),
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

List<_StackedEventMarker> _stackedEventMarkers(
  MealChartBounds bounds,
  MealAnalysisData analysis,
) {
  final usedLevelsByMinute = <int, int>{};
  return analysis.timelineEvents.map((event) {
    final x = bounds.minutesFromStart(event.timestamp);
    final minute = x.round();
    final level = usedLevelsByMinute.update(
      minute,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    final baseY = _glucoseYAt(analysis.glucoseReadings, event.timestamp);
    final aboveLineY = baseY + level * 22;
    final belowLineY = baseY - level * 22;
    final y = (aboveLineY <= bounds.maxY - 14 ? aboveLineY : belowLineY).clamp(
      bounds.minY + 14,
      bounds.maxY - 14,
    );
    return _StackedEventMarker(event: event, x: x, y: y.toDouble());
  }).toList();
}

double _glucoseYAt(List<Glucose> readings, DateTime timestamp) {
  if (readings.isEmpty) return 120;

  Glucose? previous;
  Glucose? next;
  for (final reading in readings) {
    if (!reading.date.isAfter(timestamp)) {
      previous = reading;
    }
    if (!reading.date.isBefore(timestamp)) {
      next = reading;
      break;
    }
  }

  if (previous != null && next != null && previous.date != next.date) {
    final totalMs = next.date.difference(previous.date).inMilliseconds;
    final offsetMs = timestamp.difference(previous.date).inMilliseconds;
    final t = (offsetMs / totalMs).clamp(0.0, 1.0);
    return previous.sgv + (next.sgv - previous.sgv) * t;
  }
  return (previous ?? next ?? readings.first).sgv.toDouble();
}

List<MealTimelineEventData> _eventsNearMinute(
  MealAnalysisData analysis,
  int minute,
) {
  final events = analysis.timelineEvents.where((event) {
    final eventMinute = event.timestamp
        .difference(analysis.chartStart)
        .inMinutes;
    return eventMinute == minute;
  }).toList();
  return _deduplicateEvents(events);
}

LineTooltipItem _tooltipItemForSpots({
  required List<LineBarSpot> spots,
  required MealAnalysisData analysis,
  required MealChartBounds bounds,
  required TextStyle textStyle,
}) {
  final eventMinute = _eventMinuteForSpots(analysis, spots);
  final minute = eventMinute ?? spots.first.x.round();
  final time = analysis.chartStart.add(Duration(minutes: minute));
  final events = eventMinute == null
      ? const <MealTimelineEventData>[]
      : _eventsNearMinute(analysis, eventMinute);

  if (events.isNotEmpty) {
    final lines = events.map((event) {
      final value = event.value?.replaceAll('\n', ' ');
      if (value == null || value.trim().isEmpty) {
        return event.label;
      }
      return '${event.label}: $value';
    }).toList();
    return LineTooltipItem(
      '${_formatTime(time)}\n${lines.join('\n')}',
      textStyle,
    );
  }

  final glucose = _glucoseYAt(
    analysis.glucoseReadings,
    analysis.chartStart.add(Duration(minutes: minute)),
  ).clamp(bounds.minY, bounds.maxY);
  return LineTooltipItem(
    '${_formatTime(time)}\n${glucose.round()} mg/dL',
    textStyle,
  );
}

int? _eventMinuteForSpots(MealAnalysisData analysis, List<LineBarSpot> spots) {
  for (final spot in spots) {
    final minute = spot.x.round();
    if (_eventsNearMinute(analysis, minute).isNotEmpty) {
      return minute;
    }
  }
  return null;
}

List<MealTimelineEventData> _deduplicateEvents(
  Iterable<MealTimelineEventData> events,
) {
  final seen = <String>{};
  final unique = <MealTimelineEventData>[];
  for (final event in events) {
    final key = [
      event.timestamp.millisecondsSinceEpoch,
      event.type.name,
      event.label,
      event.value ?? '',
      event.activityLogId ?? '',
      event.mealId ?? '',
    ].join('|');
    if (seen.add(key)) {
      unique.add(event);
    }
  }
  return unique;
}

class _StackedEventMarker {
  final MealTimelineEventData event;
  final double x;
  final double y;

  const _StackedEventMarker({
    required this.event,
    required this.x,
    required this.y,
  });
}

class MealDeviceMetricChart extends StatelessWidget {
  final MealAnalysisData analysis;
  final MealDeviceMetric metric;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime>? onTimestampSelected;

  const MealDeviceMetricChart({
    super.key,
    required this.analysis,
    required this.metric,
    this.selectedTimestamp,
    this.onTimestampSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (analysis.deviceStatuses.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Brak device status w tym okresie')),
      );
    }

    final bounds = MealChartBounds.fromDeviceStatuses(analysis, metric);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: bounds.totalMinutes,
          minY: 0,
          maxY: bounds.maxY,
          clipData: const FlClipData.all(),
          extraLinesData: _extraLines(bounds, selectedTimestamp),
          lineBarsData: [
            LineChartBarData(
              spots: analysis.deviceStatuses
                  .map(
                    (status) => FlSpot(
                      bounds.minutesFromStart(status.date),
                      metric.value(status),
                    ),
                  )
                  .toList(),
              color: metric.color,
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
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              final spot = response?.lineBarSpots?.firstOrNull;
              if (spot == null || !event.isInterestedForInteractions) {
                return;
              }
              onTimestampSelected?.call(
                analysis.chartStart.add(Duration(minutes: spot.x.round())),
              );
            },
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
          interval: math.max(15, bounds.totalMinutes / 4).toDouble(),
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

enum MealDeviceMetric {
  cob(label: 'COB', unit: 'g', color: Colors.green),
  iob(label: 'IOB', unit: 'U', color: Colors.blue);

  final String label;
  final String unit;
  final Color color;

  const MealDeviceMetric({
    required this.label,
    required this.unit,
    required this.color,
  });

  double value(DeviceStatus status) {
    return switch (this) {
      MealDeviceMetric.cob => status.cob,
      MealDeviceMetric.iob => status.iob,
    };
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

  factory MealChartBounds.fromDeviceStatuses(
    MealAnalysisData analysis,
    MealDeviceMetric metric,
  ) {
    final maxValue = analysis.deviceStatuses
        .map(metric.value)
        .fold<double>(0, math.max);
    return MealChartBounds(
      start: analysis.chartStart,
      end: analysis.chartEnd,
      minY: 0,
      maxY: math.max(metric == MealDeviceMetric.iob ? 2 : 10, maxValue + 2),
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

ExtraLinesData _extraLines(MealChartBounds bounds, DateTime? timestamp) {
  if (timestamp == null) {
    return const ExtraLinesData();
  }
  return ExtraLinesData(
    verticalLines: [
      VerticalLine(
        x: bounds.minutesFromStart(timestamp),
        color: Colors.black.withValues(alpha: 0.45),
        strokeWidth: 1.2,
        dashArray: [4, 4],
      ),
    ],
  );
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

IconData _eventIcon(MealTimelineEventType type) {
  return switch (type) {
    MealTimelineEventType.insulin => Icons.vaccines,
    MealTimelineEventType.carbs => Icons.bakery_dining,
    MealTimelineEventType.correction => Icons.medical_services,
    MealTimelineEventType.activity => Icons.directions_run,
    MealTimelineEventType.mealStatus => Icons.flag,
    MealTimelineEventType.meal => Icons.restaurant,
    MealTimelineEventType.deviceStatus => Icons.sensors,
  };
}

class _TimelineEventIconPainter extends FlDotPainter {
  final IconData icon;
  final Color color;
  static const double size = 20;

  const _TimelineEventIconPainter({required this.icon, required this.color});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(offsetInCanvas, size / 2, backgroundPaint);
    canvas.drawCircle(offsetInCanvas, size / 2, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: size * 0.58,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      offsetInCanvas - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  Size getSize(FlSpot spot) => Size.square(size);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [icon, color, size];
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
