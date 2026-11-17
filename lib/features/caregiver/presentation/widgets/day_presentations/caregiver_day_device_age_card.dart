import 'package:flutter/material.dart';

import '../../../../../common/devices/device_detection_service.dart';
import '../../../../../common/devices/presentation/pump_silhouette_icon.dart';
import '../../../../../common/devices/presentation/sensor_silhouette_icon.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/data_warning_indicator.dart';
import '../../../../day_analysis/domain/models/day_context.dart';

/// Kompaktowy kafelek wieku sensora i poda dla widoku dnia opiekuna.
class CaregiverDayDeviceAgeCard extends StatelessWidget {
  const CaregiverDayDeviceAgeCard({super.key, required this.day});
  final DayContext day;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final sensorType = DeviceDetectionService.detectSensor(null);
    final pumpType = DeviceDetectionService.detectPump();

    String formatAge(Duration? value, DayDataSource source) {
      if (day.failedSources.contains(source)) return lang.daySourceUnavailable;
      if (value == null) return lang.dayDeviceAgeUnknown;
      return lang.dayDeviceAgeValue(value.inDays, value.inHours % 24);
    }

    final sensorFailed = day.failedSources.contains(DayDataSource.sensorAge);
    final podFailed = day.failedSources.contains(DayDataSource.podAge);

    final sensorAgeText = formatAge(day.sensorAge, DayDataSource.sensorAge);
    final podAgeText = formatAge(day.podAge, DayDataSource.podAge);

    Widget buildTile({
      required Widget icon,
      required String label,
      required String value,
      required bool hasWarning,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasWarning ? const Color(0xFFEF4444).withValues(alpha: 0.6) : borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasWarning ? const Color(0xFFEF4444) : numColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasWarning) ...[
                const SizedBox(width: 4),
                DataWarningIndicator(message: value),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          buildTile(
            icon: SensorSilhouetteIcon(
              type: sensorType,
              size: 16,
              color: const Color(0xFF00A3FF),
            ),
            label: lang.daySensorAge,
            value: sensorAgeText,
            hasWarning: sensorFailed,
          ),
          const SizedBox(width: 8),
          buildTile(
            icon: PumpSilhouetteIcon(
              type: pumpType,
              size: 16,
              color: const Color(0xFFF59E0B),
            ),
            label: lang.dayPodAge,
            value: podAgeText,
            hasWarning: podFailed,
          ),
        ],
      ),
    );
  }
}
