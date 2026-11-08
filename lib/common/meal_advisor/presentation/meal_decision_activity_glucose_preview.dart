import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/model/glucose.dart';
import '../../family_sync/family_access_scope.dart';
import '../../l10n/language.dart';
import '../../presentation/details/nightscout_record_history.dart';

/// Fetches only the completed session interval from the caregiver's own source.
class MealDecisionActivityGlucosePreview extends StatelessWidget {
  const MealDecisionActivityGlucosePreview({
    super.key,
    required this.scope,
    required this.logId,
    required this.start,
    required this.end,
  });
  final FamilyAccessScope scope;
  final int logId;
  final DateTime start, end;

  @override
  Widget build(BuildContext context) {
    if (!scope.isCurrent || !end.isAfter(start)) return const SizedBox.shrink();
    return NightscoutRecordHistory<List<Glucose>>(
      expandFallback: false,
      recordKey: (scope.uid, scope.owner, scope.source, logId, start, end),
      load: (ref, history) async {
        scope.requireCurrent();
        final readings = await history.glucose.fetchGlucoseBetween(start, end);
        scope.requireCurrent();
        return readings;
      },
      builder: (readings) => scope.isCurrent
          ? MealDecisionActivityGlucoseChart(
              readings: readings,
              start: start,
              end: end,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Compact recorded history; long missing-sample gaps remain disconnected.
class MealDecisionActivityGlucoseChart extends StatelessWidget {
  const MealDecisionActivityGlucoseChart({
    super.key,
    required this.readings,
    required this.start,
    required this.end,
  });
  final List<Glucose> readings;
  final DateTime start, end;

  @override
  Widget build(BuildContext context) {
    final data =
        readings
            .where(
              (g) =>
                  g.type == GlucoseType.cgm &&
                  g.sgv > 0 &&
                  !g.date.isBefore(start) &&
                  !g.date.isAfter(end),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final spots = <FlSpot>[];
    DateTime? previous;
    for (final reading in data) {
      if (previous != null &&
          reading.date.difference(previous) > const Duration(minutes: 10)) {
        spots.add(FlSpot.nullSpot);
      }
      spots.add(
        FlSpot(
          reading.date.difference(start).inMilliseconds / 60000,
          reading.sgv.toDouble(),
        ),
      );
      previous = reading.date;
    }
    final color = Theme.of(context).colorScheme.primary;
    final maxY = data.fold<double>(
      250,
      (max, g) => math.max(max, (g.sgv / 50).ceil() * 50.0),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${context.lang.mealDecisionActivityGlucoseHistory} · mg/dl',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          if (data.isEmpty || !end.isAfter(start))
            Text(
              context.lang.commonNoGlucoseReadings,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            SizedBox(
              height: 72,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  minY: 0,
                  maxY: maxY,
                  maxX: end.difference(start).inMilliseconds / 60000,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 10,
                        getTitlesWidget: (value, meta) =>
                            value == 70 || value == 180 || value == maxY
                            ? Text(
                                value.toInt().toString(),
                                style: Theme.of(context).textTheme.labelSmall,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: color,
                      barWidth: 2,
                      isCurved: false,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
                duration: Duration.zero,
              ),
            ),
        ],
      ),
    );
  }
}
