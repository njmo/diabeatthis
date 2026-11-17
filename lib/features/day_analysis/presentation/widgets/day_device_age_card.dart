import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/data_warning_indicator.dart';
import '../../domain/models/day_context.dart';

class DayDeviceAgeCard extends StatelessWidget {
  final DayContext day;
  const DayDeviceAgeCard({super.key, required this.day});

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

    String age(Duration? value, DayDataSource source) {
      if (day.failedSources.contains(source)) return lang.daySourceUnavailable;
      if (value == null) return lang.dayDeviceAgeUnknown;
      return lang.dayDeviceAgeValue(value.inDays, value.inHours % 24);
    }

    final warnings = [
      if (day.sensorAge == null ||
          day.failedSources.contains(DayDataSource.sensorAge))
        '${lang.daySensorAge}: ${age(day.sensorAge, DayDataSource.sensorAge)}',
      if (day.podAge == null ||
          day.failedSources.contains(DayDataSource.podAge))
        '${lang.dayPodAge}: ${age(day.podAge, DayDataSource.podAge)}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sensor
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A3FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sensors,
                        size: 16,
                        color: Color(0xFF00A3FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.daySensorAge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: numColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      age(day.sensorAge, DayDataSource.sensorAge),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 16,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                ),
                // Pod
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.dayPodAge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: numColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      age(day.podAge, DayDataSource.podAge),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: DataWarningIndicator(message: warnings.join('\n')),
            ),
          ],
        ],
      ),
    );
  }
}
