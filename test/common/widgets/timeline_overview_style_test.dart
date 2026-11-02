import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('overview softens decoration without changing glucose or gaps', (tester) async {
    final start = DateTime(2026, 11, 2, 12);
    final readings = [
      for (final minute in [0, 5, 30])
        Glucose(externalId: null, source: GlucoseSource.cloud, date: start.add(Duration(minutes: minute)), sgv: 100 + minute, direction: 'Flat'),
    ];
    Future<LineChartData> render(bool overview) async {
      await tester.pumpWidget(localizedMaterialApp(home: Scaffold(body: TimelineGlucoseChart(chartStart: start, chartEnd: start.add(const Duration(hours: 1)), glucoseReadings: readings, overviewStyle: overview))));
      await tester.pumpAndSettle();
      return tester.widget<LineChart>(find.byType(LineChart)).data;
    }
    final detailed = await render(false);
    final overview = await render(true);
    expect(overview.borderData.show, isFalse);
    expect(overview.lineBarsData.map((bar) => bar.spots).toList(), detailed.lineBarsData.map((bar) => bar.spots).toList());
    expect(overview.minY, detailed.minY);
    expect(overview.maxY, detailed.maxY);
    expect(overview.rangeAnnotations.horizontalRangeAnnotations, detailed.rangeAnnotations.horizontalRangeAnnotations);
    expect(tester.takeException(), isNull);
  });
}
