import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
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
import '../widgets/activity_low_treatments_section.dart';

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
      appBar: AppBar(title: Text(context.lang.activityLogTitle)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.lang.activityError(error))),
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
                          label: Text(context.lang.activityViewActivity),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (log.endedAt == null)
                DetailSectionCard(
                  title: context.lang.activityAnalysisTitle,
                  children: [
                    DetailInfoRow(
                      icon: Icons.insights,
                      label: context.lang.activityStatusLabel,
                      value: context.lang.activityAnalysisAvailableAfterFinish,
                    ),
                  ],
                )
              else
                state.analysis.when(
                  loading: () => DetailSectionCard(
                    title: context.lang.activityAnalysisTitle,
                    children: [
                      DetailInfoRow(
                        icon: Icons.insights,
                        label: context.lang.activityStatusLabel,
                        value: context.lang.activityAnalysisLoading,
                      ),
                    ],
                  ),
                  error: (error, _) => DetailSectionCard(
                    title: context.lang.activityAnalysisTitle,
                    children: [
                      DetailInfoRow(
                        icon: Icons.cloud_off,
                        label: 'Nightscout',
                        value: error.toString(),
                        valueColor: scheme.error,
                      ),
                    ],
                  ),
                  data: (analysis) {
                    if (analysis == null) {
                      return const SizedBox.shrink();
                    }

                    return _ActivityAnalysisSection(
                      analysis: analysis,
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
                    );
                  },
                ),
              const SizedBox(height: 12),
              ActivityLowTreatmentsSection(
                lowTreatments: state.lowTreatments,
                activityStart: log.startedAt,
              ),
              if (state.lowTreatments.isNotEmpty) const SizedBox(height: 12),
              DetailSectionCard(
                title: context.lang.activityTimeTitle,
                children: [
                  DetailInfoRow(
                    icon: Icons.play_arrow,
                    label: context.lang.activityStartLabel,
                    value: _formatDateTime(log.startedAt),
                  ),
                  DetailInfoRow(
                    icon: Icons.stop,
                    label: context.lang.activityEndLabel,
                    value: log.endedAt == null
                        ? context.lang.activityInProgress
                        : _formatDateTime(log.endedAt!),
                  ),
                  DetailInfoRow(
                    icon: Icons.timer,
                    label: context.lang.activityDurationLabel,
                    value: _formatDuration(context.lang, log.duration),
                  ),
                  DetailInfoRow(
                    icon: Icons.schedule,
                    label: context.lang.activityPlannedDurationLabel,
                    value: _formatMinutes(context.lang, log.durationMinutes),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DetailSectionCard(
                title: context.lang.activityInsulinImpactTitle,
                children: [
                  DetailInfoRow(
                    icon: Icons.schedule,
                    label: context.lang.activityBeforeMealLabel,
                    value: context.lang.activityPercentLess(log.percentagePre),
                  ),
                  DetailInfoRow(
                    icon: Icons.sports_score,
                    label: context.lang.activityAfterWorkoutLabel,
                    value: context.lang.activityPercentLess(log.percentagePost),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DetailSectionCard(
                title: context.lang.activityDetailsTitle,
                children: [
                  DetailInfoRow(
                    icon: Icons.speed,
                    label: context.lang.activityIntensityLabel,
                    value: _fallback(log.intensity),
                  ),
                  DetailInfoRow(
                    icon: Icons.notes,
                    label: context.lang.activityNotesLabel,
                    value: _fallback(log.notes),
                  ),
                  DetailInfoRow(
                    icon: Icons.sync,
                    label: context.lang.activitySyncLabel,
                    value: log.isSynced
                        ? context.lang.activitySynced
                        : context.lang.activityLocalChanges,
                    valueColor: log.isSynced ? scheme.primary : scheme.error,
                  ),
                  DetailInfoRow(
                    icon: Icons.update,
                    label: context.lang.activityLastChangedLabel,
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

  static String _formatDuration(AppLocalizations lang, Duration? duration) {
    if (duration == null) {
      return lang.activityInProgress;
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    return '${hours}h ${minutes.toString().padLeft(2, '0')} min';
  }

  static String _formatMinutes(AppLocalizations lang, int? minutes) {
    if (minutes == null) {
      return lang.activityManualStop;
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
        active ? context.lang.activityActive : context.lang.activityFinished,
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
          title: context.lang.activityChartEventsTitle,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ActivityAnalysisCharts(
                analysis: analysis,
                selectedTimestamp: selectedTimestamp,
                onTimestampSelected: onTimestampSelected,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const _LegendItem(color: Colors.green, label: '70-180'),
                  const _LegendItem(color: Colors.amber, label: '180-250'),
                  const _LegendItem(color: Colors.red, label: '<70 / >250'),
                  _LegendItem(
                    color: Colors.teal,
                    label: context.lang.activityLegendActivity,
                  ),
                  const _LegendItem(color: Colors.blue, label: 'Temp target'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DetailSectionCard(
          title: context.lang.activityStartSectionTitle,
          children: [
            DetailInfoRow(
              icon: Icons.bloodtype,
              label: context.lang.activityStartGlucoseLabel,
              value: analysis.glucoseAtStart == null
                  ? '-'
                  : '${analysis.glucoseAtStart} mg/dl',
            ),
            DetailInfoRow(
              icon: Icons.vaccines,
              label: context.lang.activityActiveInsulinLabel,
              value: analysis.iobAtStart == null
                  ? '-'
                  : '${analysis.iobAtStart!.toStringAsFixed(2)} U',
            ),
            DetailInfoRow(
              icon: Icons.grain,
              label: context.lang.activityActiveCarbsLabel,
              value: analysis.cobAtStart == null
                  ? '-'
                  : '${analysis.cobAtStart!.toStringAsFixed(1)} g',
            ),
            if (analysis.preActivityMeals.isEmpty)
              DetailInfoRow(
                icon: Icons.restaurant,
                label: context.lang.activityMealBeforeLabel,
                value: context.lang.commonNone,
              )
            else
              ...analysis.preActivityMeals.map(_MealRow.new),
          ],
        ),
        const SizedBox(height: 12),
        DetailSectionCard(
          title: context.lang.activityGlucoseSummaryTitle,
          children: [
            DetailInfoRow(
              icon: Icons.show_chart,
              label: context.lang.activityAverageGlucoseLabel,
              value: average == null ? '-' : '${average.round()} mg/dl',
            ),
            DetailInfoRow(
              icon: Icons.swap_vert,
              label: context.lang.activityRangeLabel,
              value: min == null || max == null ? '-' : '$min-$max mg/dl',
            ),
            DetailInfoRow(
              icon: Icons.bakery_dining,
              label: context.lang.activityExtraTreatLabel,
              value: treats.isEmpty
                  ? context.lang.commonNone
                  : '${treats.length} (${analysis.treatCarbsDuringActivity} g)',
            ),
            if (treats.isNotEmpty) ...treats.map(_TreatRow.new),
          ],
        ),
        const SizedBox(height: 12),
        DetailSectionCard(
          title: context.lang.activityNightscoutEventsTitle,
          children: [
            if (analysis.chartTreatments.isEmpty)
              DetailInfoRow(
                icon: Icons.event_busy,
                label: context.lang.activityChartEventsLabel,
                value: context.lang.commonNone,
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
      label: context.lang.activityMealAt(_formatTime(meal.createdAt)),
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
      label: context.lang.activityTreatAt(_formatTime(treat.createdAt)),
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
