import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/domain/model/device_status.dart';
import '../../core/domain/model/glucose.dart';

class TimelineAnalysisCharts extends StatefulWidget {
  final DateTime chartStart;
  final DateTime chartEnd;
  final DateTime? focusTimestamp;
  final DateTime? selectedTimestamp;
  final List<Glucose> glucoseReadings;
  final List<DeviceStatus> deviceStatuses;
  final List<TimelineChartEvent> events;
  final List<TimelineChartRange> ranges;
  final ValueChanged<DateTime>? onTimestampSelected;

  const TimelineAnalysisCharts({
    super.key,
    required this.chartStart,
    required this.chartEnd,
    this.focusTimestamp,
    this.selectedTimestamp,
    required this.glucoseReadings,
    required this.deviceStatuses,
    this.events = const [],
    this.ranges = const [],
    this.onTimestampSelected,
  });

  @override
  State<TimelineAnalysisCharts> createState() => _TimelineAnalysisChartsState();
}

class _TimelineAnalysisChartsState extends State<TimelineAnalysisCharts> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleFocusScroll();
  }

  @override
  void didUpdateWidget(TimelineAnalysisCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartStart != widget.chartStart ||
        oldWidget.chartEnd != widget.chartEnd ||
        oldWidget.focusTimestamp != widget.focusTimestamp) {
      _scheduleFocusScroll();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.chartEnd.difference(widget.chartStart).inMinutes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = math.max(1.0, constraints.maxWidth);
        final chartWidth = math.max(viewportWidth, minutes.abs() * 7.0);

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: chartWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TimelineGlucoseChart(
                  chartStart: widget.chartStart,
                  chartEnd: widget.chartEnd,
                  selectedTimestamp: widget.selectedTimestamp,
                  glucoseReadings: widget.glucoseReadings,
                  events: widget.events,
                  ranges: widget.ranges,
                  showBottomTitles: false,
                  onTimestampSelected: widget.onTimestampSelected,
                ),
                const SizedBox(height: 12),
                TimelineDeviceMetricChart(
                  chartStart: widget.chartStart,
                  chartEnd: widget.chartEnd,
                  selectedTimestamp: widget.selectedTimestamp,
                  deviceStatuses: widget.deviceStatuses,
                  metric: TimelineDeviceMetric.cob,
                  ranges: widget.ranges,
                  showBottomTitles: false,
                  onTimestampSelected: widget.onTimestampSelected,
                ),
                const SizedBox(height: 12),
                TimelineDeviceMetricChart(
                  chartStart: widget.chartStart,
                  chartEnd: widget.chartEnd,
                  selectedTimestamp: widget.selectedTimestamp,
                  deviceStatuses: widget.deviceStatuses,
                  metric: TimelineDeviceMetric.iob,
                  ranges: widget.ranges,
                  showBottomTitles: true,
                  onTimestampSelected: widget.onTimestampSelected,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scheduleFocusScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final timestamp = widget.focusTimestamp ?? widget.selectedTimestamp;
      if (timestamp == null) return;

      final viewportWidth = _scrollController.position.viewportDimension;
      final totalMinutes = widget.chartEnd
          .difference(widget.chartStart)
          .inMinutes
          .abs();
      if (totalMinutes <= 0) return;

      final chartWidth = viewportWidth + maxScroll;
      final offsetMinutes = timestamp
          .difference(widget.chartStart)
          .inMinutes
          .clamp(0, totalMinutes)
          .toDouble();
      final timestampX = chartWidth * offsetMinutes / totalMinutes;
      final targetOffset = (timestampX - viewportWidth * 0.25).clamp(
        0.0,
        maxScroll,
      );
      _scrollController.jumpTo(targetOffset);
    });
  }
}

class TimelineGlucoseChart extends StatelessWidget {
  final DateTime chartStart;
  final DateTime chartEnd;
  final DateTime? selectedTimestamp;
  final List<Glucose> glucoseReadings;
  final List<TimelineChartEvent> events;
  final List<TimelineChartRange> ranges;
  final bool showBottomTitles;
  final ValueChanged<DateTime>? onTimestampSelected;

  const TimelineGlucoseChart({
    super.key,
    required this.chartStart,
    required this.chartEnd,
    this.selectedTimestamp,
    required this.glucoseReadings,
    this.events = const [],
    this.ranges = const [],
    this.showBottomTitles = true,
    this.onTimestampSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (glucoseReadings.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: Text('Brak odczytów glikemii w tym okresie')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final bounds = TimelineChartBounds.fromGlucose(
      chartStart: chartStart,
      chartEnd: chartEnd,
      glucoseReadings: glucoseReadings,
    );
    final allEvents = [
      ...events,
      ...ranges.expand((range) => range.boundaryEvents),
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

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
            horizontalRangeAnnotations: _glucoseRanges(bounds),
            verticalRangeAnnotations: _verticalRanges(bounds),
          ),
          extraLinesData: _extraLines(bounds, selectedTimestamp, ranges),
          lineBarsData: [
            ..._glucoseSegments(bounds),
            ..._eventMarkers(bounds, allEvents),
          ],
          titlesData: _titles(context, bounds),
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
                chartStart.add(Duration(minutes: spot.x.round())),
              );
            },
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
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 220,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              tooltipMargin: 8,
              getTooltipItems: (spots) {
                if (spots.isEmpty) return const [];
                final tooltip = _tooltipItemForSpots(
                  spots: spots,
                  bounds: bounds,
                  readings: glucoseReadings,
                  events: allEvents,
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

  List<HorizontalRangeAnnotation> _glucoseRanges(TimelineChartBounds bounds) {
    return [
      _horizontalRange(bounds, double.negativeInfinity, 70, Colors.red, 0.08),
      _horizontalRange(bounds, 70, 180, Colors.green, 0.08),
      _horizontalRange(bounds, 180, 250, Colors.amber, 0.10),
      _horizontalRange(bounds, 250, double.infinity, Colors.red, 0.08),
    ].nonNulls.toList();
  }

  HorizontalRangeAnnotation? _horizontalRange(
    TimelineChartBounds bounds,
    double start,
    double end,
    Color color,
    double alpha,
  ) {
    final y1 = math.max(bounds.minY, start);
    final y2 = math.min(bounds.maxY, end);
    if (y1 >= y2) return null;
    return HorizontalRangeAnnotation(
      y1: y1,
      y2: y2,
      color: color.withValues(alpha: alpha),
    );
  }

  List<VerticalRangeAnnotation> _verticalRanges(TimelineChartBounds bounds) {
    return ranges.map((range) {
      return VerticalRangeAnnotation(
        x1: bounds.minutesFromStart(_maxDate(range.start, chartStart)),
        x2: bounds.minutesFromStart(_minDate(range.end, chartEnd)),
        color: range.color.withValues(alpha: range.alpha),
      );
    }).toList();
  }

  List<LineChartBarData> _glucoseSegments(TimelineChartBounds bounds) {
    if (glucoseReadings.length == 1) {
      final glucose = glucoseReadings.first;
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
    for (var i = 0; i < glucoseReadings.length - 1; i++) {
      segments.addAll(
        _splitSegment(bounds, glucoseReadings[i], glucoseReadings[i + 1]),
      );
    }
    return segments;
  }

  List<LineChartBarData> _splitSegment(
    TimelineChartBounds bounds,
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

  FlSpot _spotAt(
    TimelineChartBounds bounds,
    Glucose start,
    Glucose end,
    double t,
  ) {
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
    TimelineChartBounds bounds,
    List<TimelineChartEvent> events,
  ) {
    final markers = _stackedEventMarkers(bounds, glucoseReadings, events);
    return markers.map((marker) {
      return LineChartBarData(
        spots: [FlSpot(marker.x, marker.y)],
        color: marker.event.color,
        barWidth: 0,
        dotData: FlDotData(
          getDotPainter: (spot, percent, bar, index) {
            return _TimelineEventIconPainter(
              icon: marker.event.icon,
              color: marker.event.color,
            );
          },
        ),
      );
    }).toList();
  }

  FlTitlesData _titles(BuildContext context, TimelineChartBounds bounds) {
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
          showTitles: showBottomTitles,
          reservedSize: showBottomTitles ? 28 : 0,
          interval: math.max(15, bounds.totalMinutes / 4).toDouble(),
          getTitlesWidget: (value, meta) {
            final time = chartStart.add(Duration(minutes: value.round()));
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

class TimelineDeviceMetricChart extends StatelessWidget {
  final DateTime chartStart;
  final DateTime chartEnd;
  final DateTime? selectedTimestamp;
  final List<DeviceStatus> deviceStatuses;
  final TimelineDeviceMetric metric;
  final List<TimelineChartRange> ranges;
  final bool showBottomTitles;
  final ValueChanged<DateTime>? onTimestampSelected;

  const TimelineDeviceMetricChart({
    super.key,
    required this.chartStart,
    required this.chartEnd,
    this.selectedTimestamp,
    required this.deviceStatuses,
    required this.metric,
    this.ranges = const [],
    this.showBottomTitles = true,
    this.onTimestampSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (deviceStatuses.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('Brak danych COB/IOB w tym okresie')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final bounds = TimelineChartBounds.fromDeviceStatuses(
      chartStart: chartStart,
      chartEnd: chartEnd,
      deviceStatuses: deviceStatuses,
      metric: metric,
    );
    final spots = deviceMetricSpots(
      statuses: deviceStatuses,
      metric: metric,
      bounds: bounds,
    );

    return SizedBox(
      height: 80,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: bounds.totalMinutes,
          minY: 0,
          maxY: bounds.maxY,
          clipData: const FlClipData.all(),
          rangeAnnotations: RangeAnnotations(
            verticalRangeAnnotations: _verticalRanges(bounds),
          ),
          extraLinesData: _extraLines(bounds, selectedTimestamp, ranges),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: metric.color,
              barWidth: 3,
              isStepLineChart: true,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
          titlesData: _simpleTitles(context, bounds),
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
                chartStart.add(Duration(minutes: spot.x.round())),
              );
            },
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final time = chartStart.add(
                    Duration(minutes: spot.x.round()),
                  );
                  return LineTooltipItem(
                    '${_formatTime(time)}\n${metric.label}: ${_formatMetricValue(spot.y)} ${metric.unit}',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

  FlTitlesData _simpleTitles(BuildContext context, TimelineChartBounds bounds) {
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
          showTitles: showBottomTitles,
          reservedSize: showBottomTitles ? 28 : 0,
          interval: math.max(15, bounds.totalMinutes / 4).toDouble(),
          getTitlesWidget: (value, meta) {
            final time = chartStart.add(Duration(minutes: value.round()));
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

  List<VerticalRangeAnnotation> _verticalRanges(TimelineChartBounds bounds) {
    return ranges.map((range) {
      return VerticalRangeAnnotation(
        x1: bounds.minutesFromStart(_maxDate(range.start, chartStart)),
        x2: bounds.minutesFromStart(_minDate(range.end, chartEnd)),
        color: range.color.withValues(alpha: range.alpha),
      );
    }).toList();
  }
}

class TimelineChartEvent {
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String label;
  final String? value;

  const TimelineChartEvent({
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.label,
    this.value,
  });
}

class TimelineChartRange {
  final DateTime start;
  final DateTime end;
  final Color color;
  final double alpha;
  final String label;
  final IconData startIcon;
  final IconData endIcon;
  final String startLabel;
  final String endLabel;

  const TimelineChartRange({
    required this.start,
    required this.end,
    required this.color,
    this.alpha = 0.12,
    required this.label,
    required this.startIcon,
    required this.endIcon,
    required this.startLabel,
    required this.endLabel,
  });

  List<TimelineChartEvent> get boundaryEvents {
    return [
      TimelineChartEvent(
        timestamp: start,
        icon: startIcon,
        color: color,
        label: startLabel,
        value: label,
      ),
      TimelineChartEvent(
        timestamp: end,
        icon: endIcon,
        color: color,
        label: endLabel,
        value: label,
      ),
    ];
  }
}

enum TimelineDeviceMetric {
  cob(label: 'COB', unit: 'g', color: Colors.green),
  iob(label: 'IOB', unit: 'U', color: Colors.blue);

  final String label;
  final String unit;
  final Color color;

  const TimelineDeviceMetric({
    required this.label,
    required this.unit,
    required this.color,
  });

  double value(DeviceStatus status) {
    return switch (this) {
      TimelineDeviceMetric.cob => status.cob,
      TimelineDeviceMetric.iob => status.iob,
    };
  }
}

class TimelineChartBounds {
  final DateTime start;
  final DateTime end;
  final double minY;
  final double maxY;
  final double totalMinutes;

  const TimelineChartBounds({
    required this.start,
    required this.end,
    required this.minY,
    required this.maxY,
    required this.totalMinutes,
  });

  factory TimelineChartBounds.fromGlucose({
    required DateTime chartStart,
    required DateTime chartEnd,
    required List<Glucose> glucoseReadings,
  }) {
    final values = glucoseReadings.map((g) => g.sgv).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final minY = minValue * 0.85;
    final maxY = maxValue * 1.15;
    return TimelineChartBounds(
      start: chartStart,
      end: chartEnd,
      minY: minY.toDouble(),
      maxY: math.max(minY + 1, maxY).toDouble(),
      totalMinutes: _totalMinutes(chartStart, chartEnd),
    );
  }

  factory TimelineChartBounds.fromDeviceStatuses({
    required DateTime chartStart,
    required DateTime chartEnd,
    required List<DeviceStatus> deviceStatuses,
    required TimelineDeviceMetric metric,
  }) {
    final maxValue = deviceStatuses.map(metric.value).fold<double>(0, math.max);
    return TimelineChartBounds(
      start: chartStart,
      end: chartEnd,
      minY: 0,
      maxY: _deviceMetricMaxY(maxValue),
      totalMinutes: _totalMinutes(chartStart, chartEnd),
    );
  }

  double minutesFromStart(DateTime date) {
    final minutes = date.difference(start).inMinutes.toDouble();
    return minutes.clamp(0, totalMinutes).toDouble();
  }

  static double _totalMinutes(DateTime chartStart, DateTime chartEnd) {
    return math.max(1, chartEnd.difference(chartStart).inMinutes.toDouble());
  }

  static double _deviceMetricMaxY(double maxValue) {
    if (maxValue <= 0) return 1;
    return maxValue * 1.1;
  }
}

List<FlSpot> deviceMetricSpots({
  required List<DeviceStatus> statuses,
  required TimelineDeviceMetric metric,
  required TimelineChartBounds bounds,
}) {
  if (statuses.isEmpty) return const [];

  final spots = <FlSpot>[];
  for (var index = 0; index < statuses.length; index++) {
    final status = statuses[index];
    final effectiveDate = index == 0 ? status.date : statuses[index - 1].date;
    spots.add(
      FlSpot(bounds.minutesFromStart(effectiveDate), metric.value(status)),
    );
  }

  final lastStatus = statuses.last;
  final lastX = bounds.minutesFromStart(lastStatus.date);
  if (spots.last.x < lastX) {
    spots.add(FlSpot(lastX, metric.value(lastStatus)));
  }

  return spots;
}

List<_StackedEventMarker> _stackedEventMarkers(
  TimelineChartBounds bounds,
  List<Glucose> readings,
  List<TimelineChartEvent> events,
) {
  final usedLevelsByMinute = <int, int>{};
  return events.map((event) {
    final x = bounds.minutesFromStart(event.timestamp);
    final minute = x.round();
    final level = usedLevelsByMinute.update(
      minute,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    final baseY = _glucoseYAt(readings, event.timestamp);
    final aboveLineY = baseY + level * 22;
    final belowLineY = baseY - level * 22;
    final y = (aboveLineY <= bounds.maxY - 16 ? aboveLineY : belowLineY).clamp(
      bounds.minY + 16,
      bounds.maxY - 16,
    );
    return _StackedEventMarker(event: event, x: x, y: y.toDouble());
  }).toList();
}

double _glucoseYAt(List<Glucose> readings, DateTime timestamp) {
  if (readings.isEmpty) return 120;

  Glucose? previous;
  Glucose? next;
  for (final reading in readings) {
    if (!reading.date.isAfter(timestamp)) previous = reading;
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

LineTooltipItem _tooltipItemForSpots({
  required List<LineBarSpot> spots,
  required TimelineChartBounds bounds,
  required List<Glucose> readings,
  required List<TimelineChartEvent> events,
  required TextStyle textStyle,
}) {
  final eventMinute = _eventMinuteForSpots(bounds, events, spots);
  final minute = eventMinute ?? spots.first.x.round();
  final time = bounds.start.add(Duration(minutes: minute));
  final eventsAtMinute = eventMinute == null
      ? const <TimelineChartEvent>[]
      : _eventsNearMinute(bounds, events, eventMinute);

  if (eventsAtMinute.isNotEmpty) {
    final lines = eventsAtMinute.map((event) {
      final value = event.value?.replaceAll('\n', ' ');
      if (value == null || value.trim().isEmpty) return event.label;
      return '${event.label}: $value';
    }).toList();
    return LineTooltipItem(
      '${_formatTime(time)}\n${lines.join('\n')}',
      textStyle,
    );
  }

  final glucose = _glucoseYAt(
    readings,
    bounds.start.add(Duration(minutes: minute)),
  ).clamp(bounds.minY, bounds.maxY);
  final spotValue = spots.first.y.clamp(bounds.minY, bounds.maxY);
  return LineTooltipItem(
    '${_formatTime(time)}\n${(readings.isEmpty ? spotValue : glucose).round()} mg/dL',
    textStyle,
  );
}

int? _eventMinuteForSpots(
  TimelineChartBounds bounds,
  List<TimelineChartEvent> events,
  List<LineBarSpot> spots,
) {
  for (final spot in spots) {
    final minute = spot.x.round();
    if (_eventsNearMinute(bounds, events, minute).isNotEmpty) return minute;
  }
  return null;
}

List<TimelineChartEvent> _eventsNearMinute(
  TimelineChartBounds bounds,
  List<TimelineChartEvent> events,
  int minute,
) {
  final matched = events.where((event) {
    final eventMinute = bounds.minutesFromStart(event.timestamp).round();
    return eventMinute == minute;
  }).toList();
  return _deduplicateEvents(matched);
}

List<TimelineChartEvent> _deduplicateEvents(
  Iterable<TimelineChartEvent> events,
) {
  final seen = <String>{};
  final unique = <TimelineChartEvent>[];
  for (final event in events) {
    final key = [
      event.timestamp.millisecondsSinceEpoch,
      event.icon.codePoint,
      event.label,
      event.value ?? '',
    ].join('|');
    if (seen.add(key)) unique.add(event);
  }
  return unique;
}

ExtraLinesData _extraLines(
  TimelineChartBounds bounds,
  DateTime? selectedTimestamp,
  List<TimelineChartRange> ranges,
) {
  return ExtraLinesData(
    verticalLines: [
      for (final range in ranges) ...[
        VerticalLine(
          x: bounds.minutesFromStart(range.start),
          color: range.color.withValues(alpha: 0.75),
          strokeWidth: 1,
          dashArray: [3, 3],
        ),
        VerticalLine(
          x: bounds.minutesFromStart(range.end),
          color: range.color.withValues(alpha: 0.75),
          strokeWidth: 1,
          dashArray: [3, 3],
        ),
      ],
      if (selectedTimestamp != null)
        VerticalLine(
          x: bounds.minutesFromStart(selectedTimestamp),
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

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatMetricValue(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

class _StackedEventMarker {
  final TimelineChartEvent event;
  final double x;
  final double y;

  const _StackedEventMarker({
    required this.event,
    required this.x,
    required this.y,
  });
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
