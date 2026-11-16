import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../cgm_sensor_type.dart';
import '../device_detection_service.dart';
import '../insulin_pump_type.dart';
import 'pump_silhouette_icon.dart';
import 'sensor_silhouette_icon.dart';

class DeviceStatusHudPills extends ConsumerWidget {
  final CgmSensorType sensorType;
  final InsulinPumpType pumpType;

  const DeviceStatusHudPills({
    super.key,
    this.sensorType = CgmSensorType.libre,
    this.pumpType = InsulinPumpType.omnipod,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sensorDuration = ref.watch(sensorAgeProvider).value;
    final cannulaDuration = ref.watch(canulaAgeProvider).value;

    final sensorAgeText = DeviceDetectionService.formatAgeDuration(sensorDuration);
    final cannulaAgeText = DeviceDetectionService.formatAgeDuration(cannulaDuration);

    final chipBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    // Compact Loop-style Device Pill containing Sensor & Pump icons with age
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sensor silhouette + age
          SensorSilhouetteIcon(
            type: sensorType,
            size: 16,
            color: const Color(0xFF0EA5E9),
          ),
          const SizedBox(width: 4),
          Text(
            sensorAgeText != '—' ? sensorAgeText : sensorType.shortName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          // Subtle dot divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textColor.withValues(alpha: 0.35),
              ),
            ),
          ),
          // Pump silhouette (orange Pod) + age
          PumpSilhouetteIcon(
            type: pumpType,
            size: 16,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            cannulaAgeText != '—' ? cannulaAgeText : pumpType.shortName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
