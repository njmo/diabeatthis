import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/devices/cgm_sensor_type.dart';
import '../../../../common/devices/device_detection_service.dart';
import '../../../../common/devices/insulin_pump_type.dart';
import '../../../../common/devices/presentation/pump_silhouette_icon.dart';
import '../../../../common/devices/presentation/sensor_silhouette_icon.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/dashboard/nightscout_panel_view.dart';
import '../../../../common/widgets/glucose_direction_icon.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../data/providers/blood_sugar_readings_list_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'compact_loop_glucose_chart.dart';
import 'responsive_glucose_chart.dart';

class DashboardGlucoseReading extends ConsumerWidget {
  const DashboardGlucoseReading({
    super.key,
    required this.value,
    required this.color,
    required this.trendIcon,
    this.change,
    this.readings,
    this.lastUpdate,
    this.sensorType,
    this.pumpType,
    this.showDeviceCards = true,
  });

  final int? value;
  final Color color;
  final IconData? trendIcon;
  final String? change;
  final List<Glucose>? readings;
  final String? lastUpdate;
  final CgmSensorType? sensorType;
  final InsulinPumpType? pumpType;
  final bool showDeviceCards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ścieżka kompatybilności dla testów układu panelu z pustą listą odczytów
    if (readings != null && readings!.isEmpty) {
      return Column(
        children: [
          ResponsiveGlucoseChart(readings: readings),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveLastUpdate =
        lastUpdate ?? NightscoutPanelScope.of(context)?.lastUpdate;

    // Pobranie historii jeśli potrzebne do obliczenia różnicy lub wartości
    final history =
        readings ?? ref.watch(bloodSugarReadingsListProvider).asData?.value;
    final effectiveValue = value ?? history?.firstOrNull?.sgv;

    // Kolor statusu w palecie glikemii (poniżej 70 czerwony, 70-180 zielony, 180-250 żółty, powyżej 250 czerwony)
    final Color statusColor;
    if (effectiveValue != null) {
      if (effectiveValue < 70) {
        statusColor = const Color(0xFFEF4444); // hipoglikemia (czerwony)
      } else if (effectiveValue <= 180) {
        statusColor = const Color(0xFF10B981); // norma (zielony)
      } else if (effectiveValue <= 250) {
        statusColor = const Color(0xFFF59E0B); // hiperglikemia (żółty/bursztynowy)
      } else {
        statusColor = const Color(0xFFDC2626); // znaczna hiperglikemia (czerwony)
      }
    } else {
      statusColor = color;
    }

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    // Wyznaczenie różnicy (delta)
    final effectiveDelta = _resolveDelta(history);

    // Wyznaczenie ikony trendu
    final effectiveTrendIcon = _resolveTrendIcon(history);

    // Wyznaczenie sprzętu i czasu użytkowania
    final effectiveSensor =
        sensorType ?? DeviceDetectionService.detectSensor(null);
    final effectivePump = pumpType ?? DeviceDetectionService.detectPump();

    final sensorDuration =
        showDeviceCards ? ref.watch(sensorAgeProvider).value : null;
    final cannulaDuration =
        showDeviceCards ? ref.watch(canulaAgeProvider).value : null;

    final sensorAgeText =
        DeviceDetectionService.formatAgeDuration(sensorDuration);
    final cannulaAgeText =
        DeviceDetectionService.formatAgeDuration(cannulaDuration);

    final sensorName = effectiveSensor.shortName.isNotEmpty
        ? effectiveSensor.shortName
        : effectiveSensor.displayName;
    final pumpName = effectivePump.shortName == 'Pod'
        ? 'Pod DASH'
        : (effectivePump.shortName.isNotEmpty
            ? effectivePump.shortName
            : effectivePump.displayName);

    // Tekst jednostki i świeżości odczytu
    final timeText =
        effectiveLastUpdate != null && effectiveLastUpdate.isNotEmpty
            ? effectiveLastUpdate
            : null;
    final unit = context.lang.dashboardGlucoseUnit;
    final subtitle = timeText != null ? '$unit • $timeText' : unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GÓRA: Kapsuły (Loop Duet)
        Row(
          children: [
            // 1. Kapsuła: Glikemia Hero
            Expanded(
              child: Container(
                height: 76,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            effectiveValue?.toString() ?? '??',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: numColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: -0.2,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    if ((effectiveTrendIcon != null) ||
                        (effectiveDelta != null && effectiveDelta.isNotEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (effectiveTrendIcon != null)
                              Icon(
                                effectiveTrendIcon,
                                size: 16,
                                color: statusColor,
                              ),
                            if (effectiveTrendIcon != null &&
                                effectiveDelta != null &&
                                effectiveDelta.isNotEmpty)
                              const SizedBox(width: 3),
                            if (effectiveDelta != null &&
                                effectiveDelta.isNotEmpty)
                              Text(
                                effectiveDelta,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showDeviceCards) ...[
              const SizedBox(width: 10),
              // 2. Kapsuła: Status Sprzętu (Sensor + Pompa)
              Expanded(
                child: Container(
                  height: 76,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Sensor
                      Row(
                        children: [
                          SensorSilhouetteIcon(
                            type: effectiveSensor,
                            size: 14,
                            color: const Color(0xFF00A3FF),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sensorName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: numColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            sensorAgeText ?? '--',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 1, thickness: 1, color: dividerColor),
                      // Pompa
                      Row(
                        children: [
                          PumpSilhouetteIcon(
                            type: effectivePump,
                            size: 14,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pumpName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: numColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            cannulaAgeText ?? '--',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // DÓŁ: Karta Wykresu (Glukoza)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nagłówek wewnątrz karty
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Glukoza & Predykcja Loop',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: numColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.auto_graph_rounded,
                          size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        'Cel: 110 za 2h',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Wykres z predykcją w stylu Loop
              CompactLoopGlucoseChart(
                readings: readings,
                height: 120,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _resolveDelta(List<Glucose>? history) {
    if (change != null && change!.isNotEmpty) {
      return change!
          .replaceAll(' mg/dl', '')
          .replaceAll(' mg/dL', '')
          .trim();
    }
    if (history != null && history.length >= 2) {
      final diff = history[0].sgv - history[1].sgv;
      return diff > 0 ? '+$diff' : '$diff';
    }
    return null;
  }

  IconData? _resolveTrendIcon(List<Glucose>? history) {
    if (trendIcon != null) return trendIcon;
    if (history != null && history.isNotEmpty) {
      final dir = history.first.direction;
      if (dir.isNotEmpty && dir.toUpperCase() != 'NONE') {
        return iconForDirection(dir);
      }
      if (history.length >= 2) {
        final diff = history[0].sgv - history[1].sgv;
        return iconForDirection(directionForTick(diff));
      }
    }
    return null;
  }
}
