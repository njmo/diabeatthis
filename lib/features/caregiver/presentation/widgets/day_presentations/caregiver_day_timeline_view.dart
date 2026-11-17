import 'package:flutter/material.dart';

import '../../../../../common/widgets/data_warning_indicator.dart';
import '../../../../day_analysis/domain/models/day_context.dart';
import 'caregiver_day_device_age_card.dart';
import 'caregiver_day_glucose_chart.dart';
import 'caregiver_night_summary_card.dart';

class _CaregiverTimelineItem {
  final DateTime time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _CaregiverTimelineItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class CaregiverDayTimelineView extends StatelessWidget {
  const CaregiverDayTimelineView({super.key, required this.day});
  final DayContext day;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final g = day.glucose;
    int? tir;
    int? mean = g?.mean?.round();
    int? lowMin = g?.window.belowRange.inMinutes;

    if (g != null && g.window.observed > Duration.zero) {
      tir = (g.window.inRange.inMilliseconds /
              g.window.observed.inMilliseconds *
              100)
          .round();
    }

    final hasBoluses = day.boluses != null;
    final hasBasal = day.basal != null;
    final totalBolus = (day.boluses?.manualUnits ?? 0) +
        (day.boluses?.wizardUnits ?? 0) +
        (day.boluses?.otherUnits ?? 0);
    final totalBasal = day.basal?.units ?? 0;
    final totalInsulin = (hasBoluses || hasBasal) ? totalBolus + totalBasal : null;

    Widget buildPill(String title, String value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: numColor,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildTimelineNode({
      required String time,
      required String title,
      required String subtitle,
      required IconData icon,
      required Color iconColor,
      bool isLast = false,
    }) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: borderColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: numColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Ekstrakcja rzeczywistych zdarzeń z modelu DayContext
    final events = <_CaregiverTimelineItem>[];

    if (day.wizards != null && day.wizards!.isNotEmpty) {
      for (final w in day.wizards!) {
        final time = w.date ?? w.createdAt;
        final carbs = w.carbs;
        final insulin = w.insulin;
        final parts = <String>[];
        if (carbs > 0) parts.add('${carbs.toStringAsFixed(0)}g WW');
        if (insulin > 0) parts.add('Sugestia bolusa: ${insulin.toStringAsFixed(1)}j');
        if (w.glucose > 0) parts.add('Glikemia: ${w.glucose} mg/dl');
        if (w.notes != null && w.notes!.isNotEmpty) parts.add(w.notes!);

        events.add(_CaregiverTimelineItem(
          time: time,
          title: carbs > 0 ? 'Kalkulator bolusa & posiłek' : 'Kalkulator bolusa',
          subtitle: parts.isNotEmpty ? parts.join(' · ') : 'Wpis kalkulatora',
          icon: Icons.calculate_outlined,
          color: const Color(0xFFF59E0B),
        ));
      }
    }

    if (day.carbEntries != null && day.carbEntries!.isNotEmpty) {
      for (final treat in day.carbEntries!) {
        final isDuplicate = events.any(
          (e) => (e.time.difference(treat.createdAt).inMinutes).abs() < 2,
        );
        if (!isDuplicate && treat.carbs > 0) {
          events.add(_CaregiverTimelineItem(
            time: treat.createdAt,
            title: 'Wpis węglowodanów',
            subtitle: '${treat.carbs}g WW',
            icon: Icons.restaurant_outlined,
            color: const Color(0xFF10B981),
          ));
        }
      }
    }

    if (day.lowTreatments != null && day.lowTreatments!.isNotEmpty) {
      for (final lt in day.lowTreatments!) {
        final carbs = lt.historicalCarbs ?? lt.netCarbsGrams;
        events.add(_CaregiverTimelineItem(
          time: lt.eatenAt,
          title: 'Leczenie hipoglikemii',
          subtitle: '${carbs != null ? '${carbs.toStringAsFixed(0)}g WW' : ''} szybkich węglowodanów',
          icon: Icons.medical_services_outlined,
          color: const Color(0xFFEF4444),
        ));
      }
    }

    events.sort((a, b) => a.time.compareTo(b.time));
    final hasTreatmentsFailure = day.failedSources.contains(DayDataSource.treatments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Zwięzłe kafelki wieku sprzętu (Sensor & Pod)
        CaregiverDayDeviceAgeCard(day: day),

        // 2. Rząd 4 pigułek dobowych (Top Quick HUD)
        Row(
          children: [
            buildPill(
              'TIR 24h',
              tir != null ? '$tir%' : '--',
              (tir ?? 0) >= 70 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              Icons.track_changes_rounded,
            ),
            const SizedBox(width: 6),
            buildPill(
              'Średnia',
              mean != null ? '$mean' : '--',
              const Color(0xFF00A3FF),
              Icons.bloodtype_outlined,
            ),
            const SizedBox(width: 6),
            buildPill(
              'Hipo <70',
              lowMin != null ? '${lowMin}m' : '--',
              (lowMin ?? 0) > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              Icons.warning_amber_rounded,
            ),
            const SizedBox(width: 6),
            buildPill(
              'Insulina',
              totalInsulin != null ? '${totalInsulin.toStringAsFixed(1)}j' : '--',
              const Color(0xFF8B5CF6),
              Icons.medication_liquid_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Nowoczesny wykres glikemii 24h (płynna wstęga bez pinezek)
        CaregiverDayGlucoseChart(
          day: day,
          initialStyle: CaregiverChartStyle.smoothSpline,
          showStyleSelector: false,
        ),

        // 4. Karta podsumowania poprzedniej nocy (22:00 – 06:00) widoczna bezpośrednio z kafelkami
        CaregiverNightSummaryCard(day: day),

        // 5. Oś czasu zdarzeń w ciągu dnia
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 18, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zdarzenia w ciągu dnia',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: numColor,
                      ),
                    ),
                  ),
                  if (hasTreatmentsFailure)
                    const DataWarningIndicator(
                      message: 'Dane zabiegów i zdarzeń niedostępne',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (hasTreatmentsFailure && events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Dane zabiegów i zdarzeń niedostępne',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ),
                )
              else if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 28,
                          color: mutedColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Brak zarejestrowanych zdarzeń w ciągu dnia',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(events.length, (index) {
                  final e = events[index];
                  final timeStr =
                      '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
                  return buildTimelineNode(
                    time: timeStr,
                    title: e.title,
                    subtitle: e.subtitle,
                    icon: e.icon,
                    iconColor: e.color,
                    isLast: index == events.length - 1,
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
