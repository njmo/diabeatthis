import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/devices/cgm_sensor_type.dart';
import '../../../../common/devices/device_detection_service.dart';
import '../../../../common/devices/insulin_pump_type.dart';
import '../../../../common/devices/presentation/pump_silhouette_icon.dart';
import '../../../../common/devices/presentation/sensor_silhouette_icon.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/dashboard/glucose_freshness.dart';
import '../../../../common/presentation/dashboard/glucose_freshness_provider.dart';
import '../../../../common/presentation/dashboard/nightscout_panel_view.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../data/providers/blood_sugar_readings_list_provider.dart';
import '../../data/providers/time_now_provider.dart';
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
    this.readingAt,
    this.sensorType,
    this.pumpType,
    this.showDeviceCards = true,
    this.aapsPredictionsJson,
    this.loopStatus,
  });

  final int? value;
  final Color color;
  final IconData? trendIcon;
  final String? change;
  final List<Glucose>? readings;
  final String? lastUpdate;
  final DateTime? readingAt;
  final CgmSensorType? sensorType;
  final InsulinPumpType? pumpType;
  final bool showDeviceCards;
  final String? aapsPredictionsJson;
  final DeviceStatus? loopStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = loopStatus;
    final iob = status != null && status.hasIob && status.iob.isFinite
        ? status.iob
        : null;
    final cob = status != null && status.hasCob && status.cob.isFinite
        ? status.cob
        : null;
    final showLoopMetrics = iob != null || cob != null;
    if (readings?.isEmpty == true && !showLoopMetrics) {
      return Column(
        children: [
          if (NightscoutPanelScope.of(context)?.syncRibbon case final ribbon?)
            ribbon,
          ResponsiveGlucoseChart(readings: readings),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pobranie historii jeśli potrzebne do obliczenia różnicy lub wartości
    final history =
        readings ?? ref.watch(bloodSugarReadingsListProvider).asData?.value;
    final effectiveValue = value ?? history?.firstOrNull?.sgv;
    ref.watch(timeNowProvider);
    final now = ref.watch(dashboardWallClockProvider)();
    final measuredAt =
        readingAt ?? (value == null ? history?.firstOrNull?.date : null);
    final stale =
        ref.watch(dashboardGlucoseStaleProvider(measuredAt)).asData?.value ??
        dashboardGlucoseIsStale(measuredAt, now);

    // Kolor statusu w palecie glikemii (poniżej 70 czerwony, 70-180 zielony, 180-250 żółty, powyżej 250 czerwony)
    final Color statusColor;
    if (stale) {
      statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (effectiveValue != null) {
      if (effectiveValue < 70) {
        statusColor = const Color(0xFFEF4444); // hipoglikemia (czerwony)
      } else if (effectiveValue <= 180) {
        statusColor = const Color(0xFF10B981); // norma (zielony)
      } else if (effectiveValue <= 250) {
        statusColor = const Color(
          0xFFF59E0B,
        ); // hiperglikemia (żółty/bursztynowy)
      } else {
        statusColor = const Color(
          0xFFDC2626,
        ); // znaczna hiperglikemia (czerwony)
      }
    } else {
      statusColor = color;
    }

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final numColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);

    // Wyznaczenie różnicy (delta)
    final effectiveDelta = _resolveDelta(history);

    // Wyznaczenie ikony trendu
    final effectiveTrendIcon = _resolveTrendIcon(history);

    // Wyznaczenie sprzętu i czasu użytkowania
    final effectiveSensor =
        sensorType ?? DeviceDetectionService.detectSensor(null);
    final effectivePump = pumpType ?? DeviceDetectionService.detectPump();

    final sensorDuration = showDeviceCards
        ? ref.watch(sensorAgeProvider).value
        : null;
    final cannulaDuration = showDeviceCards
        ? ref.watch(canulaAgeProvider).value
        : null;

    final sensorAgeText = DeviceDetectionService.formatAgeDuration(
      sensorDuration,
    );
    final cannulaAgeText = DeviceDetectionService.formatAgeDuration(
      cannulaDuration,
    );

    final sensorName = effectiveSensor.shortName.isNotEmpty
        ? effectiveSensor.shortName
        : effectiveSensor.displayName;
    final pumpName = effectivePump.shortName == 'Pod'
        ? 'Pod DASH'
        : (effectivePump.shortName.isNotEmpty
              ? effectivePump.shortName
              : effectivePump.displayName);

    // Tekst jednostki i świeżości odczytu
    final measuredAge = measuredAt == null ? null : now.difference(measuredAt);
    final displayAge =
        stale &&
            measuredAge != null &&
            !measuredAge.isNegative &&
            measuredAge < dashboardGlucoseFreshness
        ? dashboardGlucoseFreshness
        : measuredAge;
    final timeText = displayAge == null || displayAge.isNegative
        ? null
        : formatAgo(displayAge);
    final unit = context.lang.dashboardGlucoseUnit;
    final subtitle = timeText != null ? '$unit • $timeText' : unit;
    final cardDecoration = BoxDecoration(
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
            final wrapDevices =
                showLoopMetrics &&
                constraints.maxWidth < 330 * scale.clamp(1.0, 1.35);
            final compactGlucose =
                showLoopMetrics &&
                showDeviceCards &&
                !wrapDevices &&
                constraints.maxWidth < 410;
            final gap = showLoopMetrics ? 6.0 : 10.0;
            final height =
                76.0 + 38.0 * (scale - 1).clamp(0.0, double.infinity);
            final glucoseCard = Container(
              key: ValueKey(stale ? 'glucose-stale' : 'glucose-current'),
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: stale
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : cardBg,
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            effectiveValue?.toString() ?? '??',
                            maxLines: 1,
                            semanticsLabel: stale
                                ? '${context.lang.beforeMealStale}: ${effectiveValue ?? '—'}, $subtitle'
                                : null,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: stale ? mutedColor : numColor,
                              decoration: stale
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
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
                  if (!stale &&
                      ((effectiveTrendIcon != null) ||
                          (effectiveDelta != null &&
                              effectiveDelta.isNotEmpty)))
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compactGlucose ? 4 : 7,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (effectiveTrendIcon != null)
                            Icon(
                              effectiveTrendIcon,
                              size: compactGlucose ? 14 : 16,
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
                                fontSize: compactGlucose ? 11 : 13,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
            final deviceCard = showDeviceCards
                ? Container(
                    height: height,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: cardDecoration,
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
                              sensorAgeText,
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
                              cannulaAgeText,
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
                  )
                : null;
            final top = Row(
              children: [
                Expanded(flex: showLoopMetrics ? 11 : 1, child: glucoseCard),
                if (showLoopMetrics) ...[
                  SizedBox(width: gap),
                  Container(
                    key: const ValueKey('dashboard-loop-metrics'),
                    height: height,
                    width: (constraints.maxWidth * 0.24 * scale)
                        .clamp(76.0, 112.0)
                        .toDouble(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: cardDecoration,
                    child: _LoopMetrics(
                      iob: iob,
                      cob: cob,
                      stale: dashboardGlucoseIsStale(status?.date, now),
                      textColor: numColor,
                      mutedColor: mutedColor,
                      dividerColor: dividerColor,
                    ),
                  ),
                ],
                if (deviceCard != null && !wrapDevices) ...[
                  SizedBox(width: gap),
                  Expanded(flex: showLoopMetrics ? 13 : 1, child: deviceCard),
                ],
              ],
            );
            if (deviceCard == null || !wrapDevices) return top;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top,
                SizedBox(height: gap),
                deviceCard,
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        // DÓŁ: Karta Wykresu (Glukoza)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          decoration: cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nagłówek wewnątrz karty
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child:
                        NightscoutPanelScope.of(context)?.syncRibbon ??
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                              context.lang.daySummarySourceGlucose,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: numColor,
                              ),
                            ),
                          ],
                        ),
                  ),
                  if (stale &&
                      (history?.any(
                            (reading) =>
                                !reading.date.isAfter(now) &&
                                !reading.date.isBefore(
                                  now.subtract(const Duration(hours: 2)),
                                ),
                          ) ??
                          false))
                    Text(
                      context.lang.beforeMealStale,
                      style: TextStyle(fontSize: 11, color: mutedColor),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Wykres z predykcją w stylu Loop
              CompactLoopGlucoseChart(
                aapsPredictionsJson: aapsPredictionsJson,
                readings: readings,
                plotHeight: MediaQuery.sizeOf(context).height * 0.16,
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
      return change!.replaceAll(' mg/dl', '').replaceAll(' mg/dL', '').trim();
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

class _LoopMetrics extends StatelessWidget {
  const _LoopMetrics({
    required this.iob,
    required this.cob,
    required this.stale,
    required this.textColor,
    required this.mutedColor,
    required this.dividerColor,
  });

  final double? iob;
  final double? cob;
  final bool stale;
  final Color textColor;
  final Color mutedColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final insulinUnit = Localizations.localeOf(context).languageCode == 'pl'
        ? 'j.'
        : 'U';

    Widget metric(String label, double? value, String unit, String format) {
      final text = value == null
          ? '—'
          : '${NumberFormat(format, locale).format(value)} $unit';
      return Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                text,
                semanticsLabel: stale && value != null
                    ? '${lang.beforeMealStale}: $text'
                    : null,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: stale ? mutedColor : textColor,
                  decoration: stale && value != null
                      ? TextDecoration.lineThrough
                      : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        metric(lang.dashboardIobLabel, iob, insulinUnit, '0.##'),
        Divider(height: 1, thickness: 1, color: dividerColor),
        metric(lang.dashboardCobLabel, cob, 'g', '0.#'),
      ],
    );
  }
}
