import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../history/glucose_window_summary.dart';

/// Both series use elapsed minutes, so meals on different dates share an axis.
class GlucoseComparisonChart extends StatelessWidget {
  final GlucoseWindowSummary current;
  final GlucoseWindowSummary previous;

  const GlucoseComparisonChart({
    super.key,
    required this.current,
    required this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = [
      ...current.readings,
      ...previous.readings,
    ].map((g) => g.sgv);
    final maxValue = values.fold<double>(
      180,
      (a, b) => math.max(a, b.toDouble()),
    );
    final minutes = math.max(
      1.0,
      current.end.difference(current.start).inMinutes.toDouble(),
    );
    return SizedBox(
      height: 230,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: minutes,
          minY: 0,
          maxY: maxValue + 30,
          clipData: const FlClipData.all(),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(
                y1: 70,
                y2: 180,
                color: scheme.primary.withValues(alpha: 0.08),
              ),
            ],
          ),
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots(current),
              color: scheme.primary,
              barWidth: 3,
              dotData: FlDotData(show: current.readings.length == 1),
            ),
            LineChartBarData(
              spots: spots(previous),
              color: scheme.tertiary,
              barWidth: 3,
              dashArray: [6, 4],
              dotData: FlDotData(show: previous.readings.length == 1),
            ),
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
                reservedSize:
                    40 * MediaQuery.textScalerOf(context).scale(12) / 12,
                interval: 100,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    value.round().toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: math.max(
                  30,
                  minutes /
                      (MediaQuery.textScalerOf(context).scale(12) > 17 ? 2 : 3),
                ),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    '+${value.round()} min',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (values) => values
                  .map(
                    (value) => LineTooltipItem(
                      '+${value.x.round()} min · ${value.y.round()} mg/dl',
                      TextStyle(color: scheme.onInverseSurface),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> spots(GlucoseWindowSummary summary) {
    final result = <FlSpot>[];
    for (var i = 0; i < summary.readings.length; i++) {
      final reading = summary.readings[i];
      if (i > 0 &&
          reading.date.difference(summary.readings[i - 1].date) >
              const Duration(minutes: 10)) {
        result.add(FlSpot.nullSpot);
      }
      result.add(
        FlSpot(
          reading.date.difference(summary.start).inMilliseconds / 60000,
          reading.sgv.toDouble(),
        ),
      );
    }
    return result;
  }
}
