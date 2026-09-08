import 'package:diabeatthis/common/history/glucose_window_summary.dart';
import 'package:diabeatthis/common/widgets/glucose_comparison_chart.dart';
import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 8, 13);
  test(
    'IOB stays at the recorded timestamp and does not bridge missing history',
    () {
      final statuses = [
        statusAt(start, 1),
        statusAt(start.add(const Duration(minutes: 5)), 2),
        statusAt(start.add(const Duration(minutes: 30)), 3),
      ];
      final bounds = TimelineChartBounds.fromDeviceStatuses(
        chartStart: start,
        chartEnd: start.add(const Duration(hours: 1)),
        deviceStatuses: statuses,
        metric: TimelineDeviceMetric.iob,
      );
      expect(
        deviceMetricSpots(
          statuses: statuses.reversed.toList(),
          metric: TimelineDeviceMetric.iob,
          bounds: bounds,
        ),
        [
          const FlSpot(0, 1),
          const FlSpot(5, 2),
          FlSpot.nullSpot,
          const FlSpot(30, 3),
        ],
      );
    },
  );

  test(
    'comparison aligns different dates by elapsed time and preserves gaps',
    () {
      final previousStart = start.subtract(const Duration(days: 3));
      GlucoseWindowSummary summary(DateTime date) => GlucoseWindowSummary(
        start: date,
        end: date.add(const Duration(hours: 1)),
        readings: [
          for (final minute in [0, 5, 30])
            Glucose(
              externalId: null,
              source: GlucoseSource.cloud,
              date: date.add(Duration(minutes: minute)),
              sgv: 100 + minute,
              direction: 'Flat',
            ),
        ],
      );
      final current = summary(start);
      final previous = summary(previousStart);
      final chart = GlucoseComparisonChart(
        current: current,
        previous: previous,
      );
      expect(chart.spots(current), chart.spots(previous));
      expect(chart.spots(current)[2], FlSpot.nullSpot);
      expect(chart.spots(current).last.x, 30);
    },
  );
}

DeviceStatus statusAt(DateTime date, double iob) => DeviceStatus(
  externalId: null,
  source: DeviceStatusSource.cloud,
  date: date,
  iob: iob,
  basalIob: 0,
  bolusIob: iob,
  insulinActivity: 0,
  cob: 0,
  tick: '',
  bg: 110,
  carbsReq: 0,
  carbsReqWithin: 0,
  sensitivityRatio: 1,
  isfMgdlForCarbs: 50,
  baseBasalRate: 1,
  tempBasalRemainingMinutes: 0,
  lastBolusAmount: 0,
  lastBolusAt: '',
);
