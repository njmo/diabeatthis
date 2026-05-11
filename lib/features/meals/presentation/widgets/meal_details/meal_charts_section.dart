import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import '../../controllers/meal_details_controller.dart';
import '../meal_analysis_charts.dart';
import 'meal_detail_components.dart';

class MealChartsSection extends HookConsumerWidget {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final DateTime? selectedTimestamp;

  const MealChartsSection({
    super.key,
    required this.details,
    required this.analysis,
    required this.analysisError,
    required this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final analysis = this.analysis;
    final viewportWidth = math.max(1.0, MediaQuery.sizeOf(context).width - 64);
    final chartWidth = math.max(
      viewportWidth,
      (analysis?.chartEnd.difference(analysis.chartStart).inMinutes ?? 0) * 7.0,
    );

    useEffect(
      () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final analysis = this.analysis;
          if (analysis == null) return;
          if (!scrollController.hasClients) return;
          final maxScroll = scrollController.position.maxScrollExtent;
          if (maxScroll <= 0) return;

          final totalMinutes = analysis.chartEnd
              .difference(analysis.chartStart)
              .inMinutes
              .abs();
          if (totalMinutes <= 0) return;

          final mealOffsetMinutes = analysis.mealTime
              .difference(analysis.chartStart)
              .inMinutes
              .clamp(0, totalMinutes)
              .toDouble();
          final mealX = chartWidth * mealOffsetMinutes / totalMinutes;
          final targetOffset = (mealX - viewportWidth * 0.25).clamp(
            0.0,
            maxScroll,
          );
          scrollController.jumpTo(targetOffset);
        });
        return null;
      },
      [
        analysis?.chartStart,
        analysis?.chartEnd,
        analysis?.mealTime,
        chartWidth,
        viewportWidth,
      ],
    );

    if (analysis == null) {
      return MealSectionTile(
        title: 'Analiza glikemii',
        children: [
          MealInfoRow(
            label: 'Nightscout',
            value: analysisError ?? 'Brak danych do analizy',
          ),
        ],
      );
    }

    return MealSectionTile(
      title: 'Glikemia / COB / IOB',
      initiallyExpanded: true,
      children: [
        SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MealGlucoseChart(
                  analysis: analysis,
                  selectedTimestamp: selectedTimestamp,
                  onTimestampSelected: (timestamp) {
                    ref
                        .read(
                          mealDetailsControllerProvider(
                            details.meal.id,
                          ).notifier,
                        )
                        .selectTimestamp(timestamp);
                  },
                ),
                const SizedBox(height: 12),
                MealDeviceMetricChart(
                  analysis: analysis,
                  metric: MealDeviceMetric.cob,
                  selectedTimestamp: selectedTimestamp,
                  onTimestampSelected: (timestamp) {
                    ref
                        .read(
                          mealDetailsControllerProvider(
                            details.meal.id,
                          ).notifier,
                        )
                        .selectTimestamp(timestamp);
                  },
                ),
                const SizedBox(height: 12),
                MealDeviceMetricChart(
                  analysis: analysis,
                  metric: MealDeviceMetric.iob,
                  selectedTimestamp: selectedTimestamp,
                  onTimestampSelected: (timestamp) {
                    ref
                        .read(
                          mealDetailsControllerProvider(
                            details.meal.id,
                          ).notifier,
                        )
                        .selectTimestamp(timestamp);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
