import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/devices/device_detection_service.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../low_treatment/data/providers/low_treatment_suggestion_visibility_provider.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_sheet.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_suggestion_card.dart';
import '../../data/providers/old_reading_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'dashboard_glucose_reading.dart';
import 'glucose_dashboard.dart';

class DeviceStatusDashboard extends ConsumerWidget {
  final DeviceStatus deviceStatus;

  const DeviceStatusDashboard({
    super.key,
    required this.deviceStatus,
    this.allowLocalActions = true,
    this.readingIsOld,
    this.readings,
    this.glucose,
    this.useDeviceGlucose = true,
    this.showDeviceCards = true,
  });
  final bool allowLocalActions;
  final Glucose? glucose;
  final bool useDeviceGlucose;
  final bool? readingIsOld;
  final List<Glucose>? readings;
  final bool showDeviceCards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oldReading =
        readingIsOld ?? ref.watch<bool>(isReadingOldProvider.select((v) => v));
    final bg = deviceStatus.bg;
    final tick = parseTick(deviceStatus.tick);
    final bgColor = (oldReading)
        ? Theme.of(context).colorScheme.onSurface
        : getColorForValue(bg);
    final trendIcon = iconForDirection(directionForTick(tick));

    final sign = tick > 0 ? '+' : '';

    final detectedSensor = DeviceDetectionService.detectSensor(
      glucose?.notes ?? deviceStatus.externalId,
    );
    final detectedPump = DeviceDetectionService.detectPump(
      device: deviceStatus.externalId,
    );

    final showCards = showDeviceCards;

    return RepaintBoundary(
      child: Column(
        children: [
          if (glucose != null)
            GlucoseDashboard(
              glucose: glucose!,
              readings: readings,
              sensorType: detectedSensor,
              pumpType: detectedPump,
              showDeviceCards: showCards,
            )
          else
            DashboardGlucoseReading(
              value: useDeviceGlucose ? bg : null,
              readings: readings,
              color: bgColor,
              trendIcon: useDeviceGlucose ? trendIcon : null,
              change: useDeviceGlucose ? '$sign$tick mg/dl' : null,
              sensorType: detectedSensor,
              pumpType: detectedPump,
              showDeviceCards: showCards,
            ),
          if (allowLocalActions &&
              deviceStatus.carbsReq > 0 &&
              ref
                      .watch(
                        lowTreatmentSuggestionVisibilityProvider(
                          deviceStatus.suggestedAt ?? deviceStatus.date,
                        ),
                      )
                      .asData
                      ?.value ==
                  true) ...[
            const SizedBox(height: 4),
            LowTreatmentSuggestionCard(
              carbsReq: deviceStatus.carbsReq,
              carbsReqWithin: deviceStatus.carbsReqWithin,
              onAdd: () => showLowTreatmentSheet(context),
            ),
          ],
        ],
      ),
    );
  }
}
