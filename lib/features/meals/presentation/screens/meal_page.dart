import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import '../controllers/meal_details_controller.dart';
import '../models/meal_page_state.dart';
import '../widgets/meal_analysis_charts.dart';

@RoutePage()
class MealPage extends ConsumerWidget {
  final int mealId;

  const MealPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealDetailsControllerProvider(mealId));

    return Scaffold(
      appBar: AppBar(
        title: state.maybeWhen(
          data: (value) => Text(value.details.meal.name),
          orElse: () => Text('Posiłek $mealId'),
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('error: $error')),
        data: (value) => _MealPageBody(state: value),
      ),
    );
  }
}

class _MealPageBody extends ConsumerWidget {
  final MealPageState state;

  const _MealPageBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = state.details;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MealHeader(state: state),
        const SizedBox(height: 12),
        _BasicInfoSection(details: details),
        _NutritionAnalysisSection(details: details),
        _MealAdvisorResultSection(details: details),
        if (details.meal.isEaten)
          _MealChartsSection(
            details: details,
            analysis: state.analysis,
            analysisError: state.analysisError,
            selectedTimestamp: state.selectedTimestamp,
          ),
        if (details.meal.isEaten && state.analysis != null)
          _LinkedEventsSection(
            mealId: details.meal.id,
            analysis: state.analysis!,
            selectedTimestamp: state.selectedTimestamp,
          ),
        _TransitionAnalysisSection(details: details),
        _SnapshotsSection(details: details),
      ],
    );
  }
}

class _MealHeader extends StatelessWidget {
  final MealPageState state;

  const _MealHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final summary = details.preferredSummarySnapshot;
    final stats = state.analysis?.glucoseStats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          details.meal.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        _MealAnalysisProgressSummary(state: state),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 720 ? 6 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.55,
          children: [
            _SummaryCard(
              label: 'Peak glucose',
              value: _mgdl(stats?.peakGlucose),
            ),
            _SummaryCard(
              label: 'Time to peak',
              value: _duration(stats?.timeToPeak),
            ),
            _SummaryCard(
              label: 'Avg glucose',
              value: _mgdl(stats?.averageGlucose?.round()),
            ),
            _SummaryCard(
              label: 'Total insulin',
              value: _units(
                state.analysis?.totalInsulinUnits ?? details.totalInsulinUnits,
              ),
            ),
            _SummaryCard(
              label: 'Total carbs',
              value: _grams(summary?.totalCarbsG),
            ),
            _SummaryCard(
              label: 'Time in range',
              value: _percent(stats?.timeInRangePercent),
            ),
          ],
        ),
      ],
    );
  }
}

class _MealAnalysisProgressSummary extends StatelessWidget {
  final MealPageState state;

  const _MealAnalysisProgressSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final analysis = state.analysis;
    if (!details.meal.isEaten) {
      return _HeaderStatusChip(
        icon: _statusIcon(details.meal.status),
        label: details.meal.status,
      );
    }
    if (analysis == null) {
      return const _HeaderStatusChip(
        icon: Icons.pending_actions,
        label: 'Analysis pending',
      );
    }
    if (!analysis.hasFullGlucoseWindow) {
      return _HeaderStatusChip(
        icon: Icons.hourglass_top,
        label: 'Analysis in progress',
        detail: 'collecting until ${_time(analysis.expectedChartEnd)}',
      );
    }
    return _HeaderStatusChip(
      icon: Icons.check_circle,
      label: 'Analysis complete',
      detail: '${analysis.postMealWindow.inMinutes} min glucose window',
    );
  }
}

class _HeaderStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;

  const _HeaderStatusChip({
    required this.icon,
    required this.label,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final text = detail == null ? label : '$label • $detail';
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: Text(text),
    );
  }
}

class _TransitionAnalysisSection extends StatelessWidget {
  final MealDetailsData details;

  const _TransitionAnalysisSection({required this.details});

  @override
  Widget build(BuildContext context) {
    final transitions = details.statusTransitions;

    return _SectionTile(
      title: 'Transition analysis',
      children: [
        if (transitions.isEmpty)
          const _InfoRow(label: 'Status history', value: '-')
        else
          for (final transition in transitions)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _statusIcon(transition.toStatus),
                color: transition.isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(_transitionLabel(transition)),
              subtitle: Text(_dateTime(transition.timestamp)),
              trailing: transition.isCurrent
                  ? const _SmallBadge(label: 'current')
                  : null,
            ),
      ],
    );
  }

  String _transitionLabel(MealStatusTransitionData transition) {
    final from = transition.fromStatus;
    if (from == null) {
      return 'Initial status: ${transition.toStatus}';
    }
    if (from == transition.toStatus) {
      return transition.toStatus;
    }
    return '$from → ${transition.toStatus}';
  }
}

class _BasicInfoSection extends StatelessWidget {
  final MealDetailsData details;

  const _BasicInfoSection({required this.details});

  @override
  Widget build(BuildContext context) {
    final meal = details.meal;

    return _SectionTile(
      title: 'Basic info',
      initiallyExpanded: true,
      children: [
        _InfoRow(label: 'Name / type', value: meal.name),
        _InfoRow(label: 'Status', value: meal.status),
        _InfoRow(label: 'Planned at', value: _dateTime(meal.plannedAt)),
        _InfoRow(
          label: 'Summarized at',
          value: _dateTimeOrDash(meal.summarizedAt),
        ),
        _InfoRow(label: 'Created at', value: _dateTime(meal.createdAt)),
        _InfoRow(label: 'Updated at', value: _dateTime(meal.updatedAt)),
        _InfoRow(label: 'Notes', value: _fallback(meal.notes)),
        _IconInfoRow(
          icon: meal.isSynced ? Icons.cloud_done : Icons.edit_location_alt,
          label: 'Sync state',
          value: meal.isSynced ? 'Synced' : 'Local',
        ),
        _BasedOnMealRow(meal: meal),
      ],
    );
  }
}

class _BasedOnMealRow extends StatelessWidget {
  final MealRecordData meal;

  const _BasedOnMealRow({required this.meal});

  @override
  Widget build(BuildContext context) {
    final basedOnMealId = meal.basedOnMealId;
    if (basedOnMealId == null) {
      return const _InfoRow(label: 'Based on meal', value: '-');
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.copy_all),
      title: const Text('Based on meal'),
      trailing: TextButton.icon(
        icon: const Icon(Icons.open_in_new),
        label: Text('#$basedOnMealId'),
        onPressed: () => context.router.push(MealRoute(mealId: basedOnMealId)),
      ),
    );
  }
}

class _NutritionAnalysisSection extends StatelessWidget {
  final MealDetailsData details;

  const _NutritionAnalysisSection({required this.details});

  @override
  Widget build(BuildContext context) {
    final snapshot = details.preferredSummarySnapshot;
    final macros = Macronutrients(
      carbsTotal: snapshot?.totalCarbsG.round() ?? 0,
      fatTotal: snapshot?.totalFatG.round() ?? 0,
      fiberTotal: snapshot?.totalFiberG.round() ?? 0,
      proteinTotal: snapshot?.totalProteinG.round() ?? 0,
    );

    return _SectionTile(
      title: 'Nutrition analysis',
      initiallyExpanded: true,
      children: [
        for (final ingredient in details.ingredients)
          _IngredientTile(ingredient: ingredient),
        const SizedBox(height: 12),
        NutrientSummaryChart(macros: macros),
        const SizedBox(height: 8),
        _ContributionBreakdown(details: details),
      ],
    );
  }
}

class _IngredientTile extends StatelessWidget {
  final MealIngredientDetailsData ingredient;

  const _IngredientTile({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canOpenIngredient = !ingredient.usesHistoricalNutrition;

    return ExpansionTile(
      leading: Icon(
        ingredient.usesHistoricalNutrition
            ? Icons.warning_amber
            : Icons.restaurant,
        color: ingredient.usesHistoricalNutrition
            ? scheme.error
            : scheme.primary,
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(ingredient.ingredientName),
          if (ingredient.isExtra) const _SmallBadge(label: 'extra'),
          if (ingredient.usesHistoricalNutrition)
            const _SmallBadge(label: 'historical nutrition'),
        ],
      ),
      subtitle: Text(
        [
          ingredient.isExtra ? 'dodane po posiłku' : 'planned',
          'portion ${ingredient.portionLabel}',
          'planned ${_number(ingredient.plannedAmount)}',
          'consumed ${_number(ingredient.effectiveConsumedAmount)}',
          '${_number(ingredient.consumedTotalGrams)}g',
        ].join(' • '),
      ),
      trailing: canOpenIngredient
          ? IconButton(
              tooltip: 'Open ingredient',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => context.router.push(
                IngredientRoute(ingredientId: ingredient.ingredientId),
              ),
            )
          : Tooltip(
              message:
                  'Ten posiłek używa historycznych wartości; link do aktualnego składnika jest nieaktywny.',
              child: Icon(Icons.link_off, color: scheme.error),
            ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        _InfoRow(label: 'Entry type', value: ingredient.entryType),
        _InfoRow(label: 'Portion', value: ingredient.portionLabel),
        _InfoRow(
          label: 'Planned amount',
          value: _number(ingredient.plannedAmount),
        ),
        _InfoRow(
          label: 'Consumed amount',
          value: _number(ingredient.effectiveConsumedAmount),
        ),
        _InfoRow(
          label: 'Quantity confidence',
          value: _confidence(ingredient.quantityConfidence),
        ),
        _InfoRow(
          label: 'Consumed confidence',
          value: _confidence(ingredient.consumedConfidence),
        ),
        _InfoRow(
          label: 'Planned total grams',
          value: _grams(ingredient.plannedTotalGrams),
        ),
        _InfoRow(
          label: 'Consumed total grams',
          value: _grams(ingredient.consumedTotalGrams),
        ),
        _InfoRow(label: 'Prep method', value: _fallback(ingredient.prepMethod)),
        _InfoRow(label: 'Notes', value: _fallback(ingredient.notes)),
        const SizedBox(height: 8),
        _NutritionComparisonTable(ingredient: ingredient),
      ],
    );
  }
}

class _NutritionComparisonTable extends StatelessWidget {
  final MealIngredientDetailsData ingredient;

  const _NutritionComparisonTable({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('Nutrition')),
          DataColumn(label: Text('Planned used')),
          DataColumn(label: Text('Consumed used')),
          DataColumn(label: Text('Current')),
        ],
        rows: [
          _nutritionRow(
            'Carbs/100g',
            ingredient.plannedNutrition.carbsPer100g,
            ingredient.consumedNutrition.carbsPer100g,
            ingredient.currentNutrition.carbsPer100g,
            'g',
          ),
          _nutritionRow(
            'Fat/100g',
            ingredient.plannedNutrition.fatPer100g,
            ingredient.consumedNutrition.fatPer100g,
            ingredient.currentNutrition.fatPer100g,
            'g',
          ),
          _nutritionRow(
            'Fiber/100g',
            ingredient.plannedNutrition.fiberPer100g,
            ingredient.consumedNutrition.fiberPer100g,
            ingredient.currentNutrition.fiberPer100g,
            'g',
          ),
          _nutritionRow(
            'Protein/100g',
            ingredient.plannedNutrition.proteinPer100g,
            ingredient.consumedNutrition.proteinPer100g,
            ingredient.currentNutrition.proteinPer100g,
            'g',
          ),
          _nutritionRow(
            'Confidence',
            ingredient.plannedNutrition.nutritionConfidence,
            ingredient.consumedNutrition.nutritionConfidence,
            ingredient.currentNutrition.nutritionConfidence,
            '',
          ),
        ],
      ),
    );
  }

  DataRow _nutritionRow(
    String label,
    double planned,
    double consumed,
    double current,
    String unit,
  ) {
    return DataRow(
      cells: [
        DataCell(Text(label)),
        DataCell(Text(_nutritionValue(planned, unit))),
        DataCell(Text(_nutritionValue(consumed, unit))),
        DataCell(Text(_nutritionValue(current, unit))),
      ],
    );
  }
}

class _MealAdvisorResultSection extends StatelessWidget {
  final MealDetailsData details;

  const _MealAdvisorResultSection({required this.details});

  @override
  Widget build(BuildContext context) {
    final decision = details.advisorDecision;

    return _SectionTile(
      title: 'Meal advisor result',
      children: [
        if (decision == null)
          const _InfoRow(label: 'Result', value: '-')
        else ...[
          _InfoRow(label: 'Result', value: decision.result),
          _InfoRow(
            label: 'Initial wait',
            value: '${decision.initialWaitTime} min',
          ),
          _InfoRow(label: 'Final wait', value: '${decision.finalWaitTime} min'),
          _InfoRow(
            label: 'Wait ignored',
            value: decision.waitTimeIgnored ? 'yes' : 'no',
          ),
          _InfoRow(
            label: 'Decision reason',
            value: _fallback(decision.decisionReason),
          ),
          _InfoRow(label: 'Version', value: decision.version.toString()),
          _InfoRow(label: 'Created at', value: _dateTime(decision.createdAt)),
          _InfoRow(label: 'Updated at', value: _dateTime(decision.updatedAt)),
        ],
      ],
    );
  }
}

class _ContributionBreakdown extends StatelessWidget {
  final MealDetailsData details;

  const _ContributionBreakdown({required this.details});

  @override
  Widget build(BuildContext context) {
    final totalCarbs = details.ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedCarbsContribution,
    );
    final totalFat = details.ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedFatContribution,
    );
    final totalCalories = details.ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedCaloriesContribution,
    );

    return Column(
      children: [
        for (final ingredient in details.ingredients)
          _InfoRow(
            label: ingredient.ingredientName,
            value:
                'carbs ${_share(ingredient.consumedCarbsContribution, totalCarbs)} • fat ${_share(ingredient.consumedFatContribution, totalFat)} • kcal ${_share(ingredient.consumedCaloriesContribution, totalCalories)} • WBT ${_number(ingredient.consumedWbtKcalContribution)} kcal',
          ),
      ],
    );
  }
}

class _MealChartsSection extends ConsumerWidget {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final DateTime? selectedTimestamp;

  const _MealChartsSection({
    required this.details,
    required this.analysis,
    required this.analysisError,
    required this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = this.analysis;
    if (analysis == null) {
      return _SectionTile(
        title: 'Glucose analysis',
        children: [
          _InfoRow(
            label: 'Nightscout',
            value: analysisError ?? 'No analysis available',
          ),
        ],
      );
    }

    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 64,
      analysis.chartEnd.difference(analysis.chartStart).inMinutes * 7.0,
    );

    return _SectionTile(
      title: 'Glucose / COB / IOB',
      initiallyExpanded: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MealGlucoseChart(
                  analysis: analysis,
                  selectedTimestamp: selectedTimestamp,
                  onTimestampSelected: (timestamp) {
                    ref
                        .read(
                          mealDetailsControllerProvider(
                            details.meal.id,
                          ).notifier,
                        )
                        .selectTimestamp(timestamp);
                  },
                ),
                const SizedBox(height: 12),
                MealDeviceMetricChart(
                  analysis: analysis,
                  metric: MealDeviceMetric.cob,
                  selectedTimestamp: selectedTimestamp,
                  onTimestampSelected: (timestamp) {
                    ref
                        .read(
                          mealDetailsControllerProvider(
                            details.meal.id,
                          ).notifier,
                        )
                        .selectTimestamp(timestamp);
                  },
                ),
                const SizedBox(height: 12),
                MealDeviceMetricChart(
                  analysis: analysis,
                  metric: MealDeviceMetric.iob,
                  selectedTimestamp: selectedTimestamp,
                  onTimestampSelected: (timestamp) {
                    ref
                        .read(
                          mealDetailsControllerProvider(
                            details.meal.id,
                          ).notifier,
                        )
                        .selectTimestamp(timestamp);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkedEventsSection extends ConsumerWidget {
  final int mealId;
  final MealAnalysisData analysis;
  final DateTime? selectedTimestamp;

  const _LinkedEventsSection({
    required this.mealId,
    required this.analysis,
    required this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionTile(
      title: 'Activity analysis',
      children: [
        _EventTimeline(
          events: analysis.timelineEvents,
          selectedTimestamp: selectedTimestamp,
          onSelected: (timestamp) {
            ref
                .read(mealDetailsControllerProvider(mealId).notifier)
                .selectTimestamp(timestamp);
          },
        ),
        const SizedBox(height: 8),
        for (final event in analysis.timelineEvents)
          ListTile(
            dense: true,
            leading: Icon(
              _eventIcon(event.type),
              color: _eventColor(event.type),
            ),
            title: Text('${_time(event.timestamp)} • ${event.label}'),
            subtitle: event.value == null ? null : Text(event.value!),
            trailing: event.activityLogId != null || event.mealId != null
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: event.activityLogId != null
                ? () => context.router.push(
                    ActivityLogRoute(activityLogId: event.activityLogId!),
                  )
                : event.mealId != null
                ? () => context.router.push(MealRoute(mealId: event.mealId!))
                : null,
            onLongPress: () {
              ref
                  .read(mealDetailsControllerProvider(mealId).notifier)
                  .selectTimestamp(event.timestamp);
            },
          ),
      ],
    );
  }
}

class _SnapshotsSection extends StatelessWidget {
  final MealDetailsData details;

  const _SnapshotsSection({required this.details});

  @override
  Widget build(BuildContext context) {
    final rows = _snapshotRows(details);

    return _SectionTile(
      title: 'Advisor snapshots',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Field')),
              DataColumn(label: Text('Planned')),
              DataColumn(label: Text('Consumed')),
              DataColumn(label: Text('Difference')),
            ],
            rows: rows.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row.label)),
                  DataCell(Text(_snapshotValue(row.plannedValue, row.unit))),
                  DataCell(Text(_snapshotValue(row.consumedValue, row.unit))),
                  DataCell(Text(_snapshotDiff(row.difference, row.unit))),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        for (final ingredient in details.ingredients.where((i) => i.isExtra))
          _InfoRow(
            label: 'Extra ingredient',
            value:
                '${ingredient.ingredientName}: ${_number(ingredient.consumedTotalGrams)}g',
          ),
      ],
    );
  }
}

class _EventTimeline extends StatelessWidget {
  final List<MealTimelineEventData> events;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime> onSelected;

  const _EventTimeline({
    required this.events,
    required this.selectedTimestamp,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  _eventIcon(event.type),
                  size: 16,
                  color: _eventColor(event.type),
                ),
                label: Text('${_time(event.timestamp)} ${event.label}'),
                selected:
                    selectedTimestamp != null &&
                    selectedTimestamp!
                            .difference(event.timestamp)
                            .inMinutes
                            .abs() <=
                        2,
                onSelected: (_) => onSelected(event.timestamp),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SectionTile({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _IconInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;

  const _SmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

List<MealSnapshotComparisonRowData> _snapshotRows(MealDetailsData details) {
  final planned = details.plannedSnapshot;
  final consumed = details.consumedSnapshot;
  return [
    MealSnapshotComparisonRowData(
      label: 'Carbs',
      plannedValue: planned?.totalCarbsG,
      consumedValue: consumed?.totalCarbsG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Fat',
      plannedValue: planned?.totalFatG,
      consumedValue: consumed?.totalFatG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Protein',
      plannedValue: planned?.totalProteinG,
      consumedValue: consumed?.totalProteinG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Fiber',
      plannedValue: planned?.totalFiberG,
      consumedValue: consumed?.totalFiberG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Calories',
      plannedValue: planned?.totalCaloriesKcal,
      consumedValue: consumed?.totalCaloriesKcal,
      unit: 'kcal',
    ),
    MealSnapshotComparisonRowData(
      label: 'Total grams',
      plannedValue: planned?.totalGrams,
      consumedValue: consumed?.totalGrams,
      unit: 'g',
    ),
  ];
}

IconData _eventIcon(MealTimelineEventType type) {
  return switch (type) {
    MealTimelineEventType.insulin => Icons.vaccines,
    MealTimelineEventType.carbs => Icons.bakery_dining,
    MealTimelineEventType.correction => Icons.medical_services,
    MealTimelineEventType.activity => Icons.directions_run,
    MealTimelineEventType.mealStatus => Icons.flag,
    MealTimelineEventType.meal => Icons.restaurant,
    MealTimelineEventType.deviceStatus => Icons.sensors,
  };
}

Color _eventColor(MealTimelineEventType type) {
  return switch (type) {
    MealTimelineEventType.insulin => Colors.blue,
    MealTimelineEventType.carbs => Colors.green,
    MealTimelineEventType.correction => Colors.deepPurple,
    MealTimelineEventType.activity => Colors.teal,
    MealTimelineEventType.mealStatus => Colors.orange,
    MealTimelineEventType.meal => Colors.brown,
    MealTimelineEventType.deviceStatus => Colors.grey,
  };
}

IconData _statusIcon(String status) {
  return switch (status) {
    'planned' => Icons.schedule,
    'bolused-waiting' => Icons.hourglass_top,
    'bolused-eating' => Icons.restaurant,
    'eaten' || 'eaten-bolused' || 'summarized' => Icons.check_circle,
    'skipped' => Icons.cancel,
    _ => Icons.flag,
  };
}

String _dateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

String _dateTimeOrDash(DateTime? date) => date == null ? '-' : _dateTime(date);

String _time(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _fallback(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return '-';
  return text;
}

String _number(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

String _mgdl(int? value) => value == null ? '-' : '$value mg/dL';

String _grams(double? value) => value == null ? '-' : '${_number(value)}g';

String _units(double? value) =>
    value == null ? '-' : '${value.toStringAsFixed(2)}U';

String _percent(double? value) => value == null ? '-' : '${value.round()}%';

String _confidence(double? value) =>
    value == null ? '-' : '${(value * 100).round()}%';

String _duration(Duration? duration) {
  if (duration == null) return '-';
  final sign = duration.isNegative ? '-' : '+';
  return '$sign${duration.inMinutes.abs()} min';
}

String _share(double value, double total) {
  if (total <= 0) return '-';
  return '${(value / total * 100).round()}%';
}

String _snapshotValue(double? value, String unit) {
  if (value == null) return '-';
  return '${_number(value)}$unit';
}

String _snapshotDiff(double? value, String unit) {
  if (value == null) return '-';
  final prefix = value > 0 ? '+' : '';
  return '$prefix${_number(value)}$unit';
}

String _nutritionValue(double value, String unit) {
  if (unit.isEmpty) {
    return _confidence(value);
  }
  return '${_number(value)}$unit';
}
