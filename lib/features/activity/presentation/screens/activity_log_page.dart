import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/widgets/detail_section_card.dart';
import '../../../../core/domain/model/correction_bolus.dart';
import '../../../../core/domain/model/extended_carb.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../controllers/activity_log_details_controller.dart';
import '../widgets/activity_glucose_chart.dart';

@RoutePage()
class ActivityLogPage extends ConsumerWidget {
  final int activityLogId;

  const ActivityLogPage({super.key, required this.activityLogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      activityLogDetailsControllerProvider(activityLogId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Log aktywności')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('error: $error')),
        data: (state) {
          final log = state.data;
          final scheme = Theme.of(context).colorScheme;
          final bottomPadding = 16 + MediaQuery.viewPaddingOf(context).bottom;

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.activityName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(log.startedAt),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(active: log.isActive),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            context.router.push(
                              routes.ActivityRoute(activityId: log.activityId),
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Zobacz aktywność'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (state.analysis != null)
                _ActivityAnalysisSection(
                  analysis: state.analysis!,
                  selectedTimestamp: state.selectedTimestamp,
                  onTimestampSelected: (timestamp) {
                    ref
                        .read(
                          activityLogDetailsControllerProvider(
                            activityLogId,
                          ).notifier,
                        )
                        .selectTimestamp(timestamp);
                  },
                )
              else if (log.endedAt == null)
                const DetailSectionCard(
                  title: 'Analiza glikemii',
                  children: [
                    DetailInfoRow(
                      icon: Icons.insights,
                      label: 'Status',
                      value: 'Dostępna po zakończeniu aktywności',
                    ),
                  ],
                )
              else if (state.analysisError != null)
                DetailSectionCard(
                  title: 'Analiza glikemii',
                  children: [
                    DetailInfoRow(
                      icon: Icons.cloud_off,
                      label: 'Nightscout',
                      value: state.analysisError!,
                      valueColor: scheme.error,
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              DetailSectionCard(
                title: 'Czas',
                children: [
                  DetailInfoRow(
                    icon: Icons.play_arrow,
                    label: 'Start',
                    value: _formatDateTime(log.startedAt),
                  ),
                  DetailInfoRow(
                    icon: Icons.stop,
                    label: 'Koniec',
                    value: log.endedAt == null
                        ? 'W trakcie'
                        : _formatDateTime(log.endedAt!),
                  ),
                  DetailInfoRow(
                    icon: Icons.timer,
                    label: 'Czas trwania',
                    value: _formatDuration(log.duration),
                  ),
                  DetailInfoRow(
                    icon: Icons.schedule,
                    label: 'Planowany czas',
                    value: _formatMinutes(log.durationMinutes),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DetailSectionCard(
                title: 'Wpływ na insulinę',
                children: [
                  DetailInfoRow(
                    icon: Icons.arrow_back,
                    label: 'Przed aktywnością',
                    value: '${log.percentagePre}%',
                  ),
                  DetailInfoRow(
                    icon: Icons.arrow_forward,
                    label: 'Po aktywności',
                    value: '${log.percentagePost}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DetailSectionCard(
                title: 'Szczegóły',
                children: [
                  DetailInfoRow(
                    icon: Icons.speed,
                    label: 'Intensywność',
                    value: _fallback(log.intensity),
                  ),
                  DetailInfoRow(
                    icon: Icons.notes,
                    label: 'Notatki',
                    value: _fallback(log.notes),
                  ),
                  DetailInfoRow(
                    icon: Icons.sync,
                    label: 'Synchronizacja',
                    value: log.isSynced ? 'Zsynchronizowane' : 'Lokalne zmiany',
                    valueColor: log.isSynced ? scheme.primary : scheme.error,
                  ),
                  DetailInfoRow(
                    icon: Icons.update,
                    label: 'Ostatnia zmiana',
                    value: _formatDateTime(log.updatedAt),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _fallback(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return '-';
    }
    return text;
  }

  static String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  static String _formatDuration(Duration? duration) {
    if (duration == null) {
      return 'W trakcie';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    return '${hours}h ${minutes.toString().padLeft(2, '0')} min';
  }

  static String _formatMinutes(int? minutes) {
    if (minutes == null) {
      return 'Do ręcznego zatrzymania';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')} min';
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;

  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = active
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = active
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        active ? 'Aktywna' : 'Zakończona',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActivityAnalysisSection extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime>? onTimestampSelected;

  const _ActivityAnalysisSection({
    required this.analysis,
    this.selectedTimestamp,
    this.onTimestampSelected,
  });

  @override
  Widget build(BuildContext context) {
    final average = analysis.averageGlucoseDuringActivity;
    final min = analysis.minGlucoseDuringActivity;
    final max = analysis.maxGlucoseDuringActivity;
    final treats = analysis.treatsDuringActivity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailSectionCard(
          title: 'Glikemia / COB / IOB i zdarzenia',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ActivityAnalysisCharts(
                analysis: analysis,
                selectedTimestamp: selectedTimestamp,
                onTimestampSelected: onTimestampSelected,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LegendItem(color: Colors.green, label: '70-180'),
                  _LegendItem(color: Colors.amber, label: '180-250'),
                  _LegendItem(color: Colors.red, label: '<70 / >250'),
                  _LegendItem(color: Colors.teal, label: 'Aktywność'),
                  _LegendItem(color: Colors.blue, label: 'Temp target'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DetailSectionCard(
          title: 'Start aktywności',
          children: [
            DetailInfoRow(
              icon: Icons.bloodtype,
              label: 'Cukier na starcie',
              value: analysis.glucoseAtStart == null
                  ? '-'
                  : '${analysis.glucoseAtStart} mg/dl',
            ),
            DetailInfoRow(
              icon: Icons.vaccines,
              label: 'Aktywna insulina',
              value: analysis.iobAtStart == null
                  ? '-'
                  : '${analysis.iobAtStart!.toStringAsFixed(2)} U',
            ),
            DetailInfoRow(
              icon: Icons.grain,
              label: 'Aktywne węglowodany',
              value: analysis.cobAtStart == null
                  ? '-'
                  : '${analysis.cobAtStart!.toStringAsFixed(1)} g',
            ),
            if (analysis.preActivityMeals.isEmpty)
              const DetailInfoRow(
                icon: Icons.restaurant,
                label: 'Posiłek do 1h przed',
                value: 'Brak',
              )
            else
              ...analysis.preActivityMeals.map(_MealRow.new),
          ],
        ),
        const SizedBox(height: 12),
        DetailSectionCard(
          title: 'Podsumowanie glikemii',
          children: [
            DetailInfoRow(
              icon: Icons.show_chart,
              label: 'Średni cukier',
              value: average == null ? '-' : '${average.round()} mg/dl',
            ),
            DetailInfoRow(
              icon: Icons.swap_vert,
              label: 'Zakres',
              value: min == null || max == null ? '-' : '$min-$max mg/dl',
            ),
            DetailInfoRow(
              icon: Icons.bakery_dining,
              label: 'Dodatkowe treat',
              value: treats.isEmpty
                  ? 'Brak'
                  : '${treats.length} (${analysis.treatCarbsDuringActivity} g)',
            ),
            if (treats.isNotEmpty) ...treats.map(_TreatRow.new),
          ],
        ),
        const SizedBox(height: 12),
        DetailSectionCard(
          title: 'Zdarzenia Nightscout',
          children: [
            if (analysis.chartTreatments.isEmpty)
              const DetailInfoRow(
                icon: Icons.event_busy,
                label: 'Zdarzenia na wykresie',
                value: 'Brak',
              )
            else
              ...analysis.chartTreatments.map(_TreatmentRow.new),
          ],
        ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  final Meal meal;

  const _MealRow(this.meal);

  @override
  Widget build(BuildContext context) {
    return DetailInfoRow(
      icon: Icons.restaurant,
      label: 'Posiłek ${_formatTime(meal.createdAt)}',
      value:
          '${meal.carbs ?? 0} g, ${meal.insulin?.toStringAsFixed(2) ?? '-'} U',
    );
  }
}

class _TreatRow extends StatelessWidget {
  final Treat treat;

  const _TreatRow(this.treat);

  @override
  Widget build(BuildContext context) {
    return DetailInfoRow(
      icon: Icons.bakery_dining,
      label: 'Treat ${_formatTime(treat.createdAt)}',
      value: '${treat.carbs} g',
    );
  }
}

class _TreatmentRow extends StatelessWidget {
  final Treatment treatment;

  const _TreatmentRow(this.treatment);

  @override
  Widget build(BuildContext context) {
    final createdAt = treatment.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(treatment.getIcon(), color: treatment.getColor()),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              createdAt == null
                  ? _treatmentName(treatment)
                  : '${_formatTime(createdAt)} • ${_treatmentName(treatment)}',
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              treatment.getParts(),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime? date) {
  if (date == null) return '-';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _treatmentName(Treatment treatment) {
  if (treatment is Meal) return 'Meal';
  if (treatment is TemporaryTarget) return 'Temp target';
  if (treatment is Treat) return 'Treat';
  if (treatment is ManualBolus) return 'Bolus';
  if (treatment is CorrectionBolus) return 'Korekta';
  if (treatment is ExtendedCarb) return 'Extended carbs';
  return 'Treatment';
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
