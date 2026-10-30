import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/carbohydrate_icon.dart';
import '../../../../common/widgets/nutrition_metric_tile.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_sheet.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_suggestion_card.dart';
import '../../data/providers/old_reading_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'dashboard_glucose_reading.dart';

class DeviceStatusDashboard extends ConsumerWidget {
  final DeviceStatus deviceStatus;

  const DeviceStatusDashboard({super.key, required this.deviceStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final oldReading = ref.watch(isReadingOldProvider.select((v) => v));
    final bg = deviceStatus.bg;
    final tick = parseTick(deviceStatus.tick);
    final bgColor = (oldReading)
        ? Theme.of(context).colorScheme.onSurface
        : getColorForValue(bg);
    final trendIcon = iconForDirection(directionForTick(tick));

    final sign = tick > 0 ? '+' : '';

    return RepaintBoundary(
      child: Column(
        children: [
          DashboardGlucoseReading(
            value: bg,
            color: bgColor,
            trendIcon: trendIcon,
            change: '$sign$tick mg/dl',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tooltip(
                  message: context.lang.mealReviewIob,
                  child: NutritionMetricTile(
                    iconSize: 30,
                    iconSpacing: 16,
                    icon: Icons.water_drop,
                    iconColor: dark
                        ? const Color(0xFF80D8F7)
                        : const Color(0xFF08799E),
                    label: context.lang.dashboardIobLabel,
                    value: '${deviceStatus.iob.toStringAsFixed(2)} U',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: context.lang.mealReviewCob,
                  child: NutritionMetricTile(
                    iconSize: 30,
                    iconSpacing: 16,
                    leading: const CarbohydrateIcon(),
                    iconColor: dark
                        ? const Color(0xFFF3C96A)
                        : const Color(0xFF986500),
                    label: context.lang.dashboardCobLabel,
                    value: '${deviceStatus.cob.toStringAsFixed(2)} g',
                  ),
                ),
              ),
            ],
          ),
          if (deviceStatus.carbsReq > 0)
            LowTreatmentSuggestionCard(
              carbsReq: deviceStatus.carbsReq,
              carbsReqWithin: deviceStatus.carbsReqWithin,
              onAdd: () => showLowTreatmentSheet(context),
            ),
        ],
      ),
    );
  }
}
