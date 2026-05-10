import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

          return ListView(
            padding: const EdgeInsets.all(16),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (state.analysis != null)
                _ActivityAnalysisSection(analysis: state.analysis!)
              else if (log.endedAt == null)
                const _SectionCard(
                  title: 'Analiza glikemii',
                  children: [
                    _InfoRow(
                      icon: Icons.insights,
                      label: 'Status',
                      value: 'Dostępna po zakończeniu aktywności',
                    ),
                  ],
                )
              else if (state.analysisError != null)
                _SectionCard(
                  title: 'Analiza glikemii',
                  children: [
                    _InfoRow(
                      icon: Icons.cloud_off,
                      label: 'Nightscout',
                      value: state.analysisError!,
                      valueColor: scheme.error,
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Czas',
                children: [
                  _InfoRow(
                    icon: Icons.play_arrow,
                    label: 'Start',
                    value: _formatDateTime(log.startedAt),
                  ),
                  _InfoRow(
                    icon: Icons.stop,
                    label: 'Koniec',
                    value: log.endedAt == null
                        ? 'W trakcie'
                        : _formatDateTime(log.endedAt!),
                  ),
                  _InfoRow(
                    icon: Icons.timer,
                    label: 'Czas trwania',
                    value: _formatDuration(log.duration),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Wpływ na insulinę',
                children: [
                  _InfoRow(
                    icon: Icons.arrow_back,
                    label: 'Przed aktywnością',
                    value: '${log.percentagePre}%',
                  ),
                  _InfoRow(
                    icon: Icons.arrow_forward,
                    label: 'Po aktywności',
                    value: '${log.percentagePost}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Szczegóły',
                children: [
                  _InfoRow(
                    icon: Icons.speed,
                    label: 'Intensywność',
                    value: _fallback(log.intensity),
                  ),
                  _InfoRow(
                    icon: Icons.notes,
                    label: 'Notatki',
                    value: _fallback(log.notes),
                  ),
                  _InfoRow(
                    icon: Icons.sync,
                    label: 'Synchronizacja',
                    value: log.isSynced ? 'Zsynchronizowane' : 'Lokalne zmiany',
                    valueColor: log.isSynced ? scheme.primary : scheme.error,
                  ),
                  _InfoRow(
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

  const _ActivityAnalysisSection({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final average = analysis.averageGlucoseDuringActivity;
    final min = analysis.minGlucoseDuringActivity;
    final max = analysis.maxGlucoseDuringActivity;
    final treats = analysis.treatsDuringActivity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Glikemia i zdarzenia',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ActivityGlucoseChart(analysis: analysis),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Start aktywności',
          children: [
            _InfoRow(
              icon: Icons.bloodtype,
              label: 'Cukier na starcie',
              value: analysis.glucoseAtStart == null
                  ? '-'
                  : '${analysis.glucoseAtStart} mg/dl',
            ),
            _InfoRow(
              icon: Icons.vaccines,
              label: 'Aktywna insulina',
              value: analysis.iobAtStart == null
                  ? '-'
                  : '${analysis.iobAtStart!.toStringAsFixed(2)} U',
            ),
            if (analysis.preActivityMeals.isEmpty)
              const _InfoRow(
                icon: Icons.restaurant,
                label: 'Posiłek do 1h przed',
                value: 'Brak',
              )
            else
              ...analysis.preActivityMeals.map(_MealRow.new),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Podsumowanie glikemii',
          children: [
            _InfoRow(
              icon: Icons.show_chart,
              label: 'Średni cukier',
              value: average == null ? '-' : '${average.round()} mg/dl',
            ),
            _InfoRow(
              icon: Icons.swap_vert,
              label: 'Zakres',
              value: min == null || max == null ? '-' : '$min-$max mg/dl',
            ),
            _InfoRow(
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
        _SectionCard(
          title: 'Zdarzenia Nightscout',
          children: [
            if (analysis.chartTreatments.isEmpty)
              const _InfoRow(
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
    return _InfoRow(
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
    return _InfoRow(
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

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...children,
          ],
        ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
