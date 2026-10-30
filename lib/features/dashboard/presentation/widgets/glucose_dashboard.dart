import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/glucose.dart';
import '../../data/providers/time_now_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'dashboard_glucose_reading.dart';

class GlucoseDashboard extends ConsumerWidget {
  const GlucoseDashboard({super.key, required this.glucose});

  final Glucose glucose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeNow = ref.watch(timeNowProvider).value;
    final lastUpdate = timeNow?.difference(glucose.date);
    final oldReading = (lastUpdate?.inMinutes ?? 0) > 10;
    final bgColor = oldReading
        ? Theme.of(context).colorScheme.onSurface
        : getColorForValue(glucose.sgv);
    final trendIcon = iconForDirection(glucose.direction);

    return RepaintBoundary(
      child: DashboardGlucoseReading(
        value: glucose.sgv,
        color: bgColor,
        trendIcon: trendIcon,
      ),
    );
  }
}
