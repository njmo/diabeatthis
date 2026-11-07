import 'package:flutter/material.dart';

import '../../../../core/domain/model/glucose.dart';
import 'mini_glucose_chart.dart';

/// Reserve the axis gutter separately so the plotted history occupies roughly
/// 80% of the panel content width rather than shrinking inside a fixed box.
class ResponsiveGlucoseChart extends StatelessWidget {
  const ResponsiveGlucoseChart({super.key, this.readings});
  final List<Glucose>? readings;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final plotWidth = available * .8;
      final width =
          (plotWidth + MiniGlucoseChart.axisWidth + MiniGlucoseChart.axisGap)
              .clamp(0.0, available);
      return Center(
        child: SizedBox(
          width: width,
          height: plotWidth / 2.6 + 24,
          child: MiniGlucoseChart(readings: readings),
        ),
      );
    },
  );
}
