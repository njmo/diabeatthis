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
        _ModeSwitches(state: state),
        const SizedBox(height: 12),
        _BasicInfoSection(details: details, detailed: state.detailedMode),
        _IngredientsSection(details: details),
        _NutrientAnalysisSection(details: details),
        if (details.meal.isEaten)
          _GlucoseAnalysisSection(
            details: details,
            analysis: state.analysis,
            analysisError: state.analysisError,
            selectedTimestamp: state.selectedTimestamp,
          ),
        if (details.meal.isEaten && state.analysis != null)
          _CobIobSection(
            mealId: details.meal.id,
            analysis: state.analysis!,
            selectedTimestamp: state.selectedTimestamp,
          ),
        if (details.meal.isEaten && state.analysis != null)
          _LinkedEventsSection(
            mealId: details.meal.id,
            analysis: state.analysis!,
            selectedTimestamp: state.selectedTimestamp,
          ),
        _SnapshotsSection(details: details),
        if (state.showRawTechnicalData)
          _DebugSection(details: details, analysis: state.analysis),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(label: details.meal.status),
            if (details.advisorDecision != null)
              _StatusChip(label: details.advisorDecision!.result),
          ],
        ),
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
              value: _units(details.totalInsulinUnits),
            ),
            _SummaryCard(
              label: 'Total carbs',
              value: summary == null ? '-' : '${summary.totalCarbsG.round()}g',
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

class _ModeSwitches extends ConsumerWidget {
  final MealPageState state;

  const _ModeSwitches({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Compact')),
            ButtonSegment(value: true, label: Text('Detailed')),
          ],
          selected: {state.detailedMode},
          onSelectionChanged: (values) {
            ref
                .read(
                  mealDetailsControllerProvider(state.details.meal.id).notifier,
                )
                .setDetailedMode(values.first);
          },
        ),
        FilterChip(
          label: const Text('Show raw technical data'),
          selected: state.showRawTechnicalData,
          onSelected: (value) {
            ref
                .read(
                  mealDetailsControllerProvider(state.details.meal.id).notifier,
                )
                .setShowRawTechnicalData(value);
          },
        ),
      ],
    );
  }
}

class _BasicInfoSection extends StatelessWidget {
  final MealDetailsData details;
  final bool detailed;

  const _BasicInfoSection({required this.details, required this.detailed});

  @override
  Widget build(BuildContext context) {
    final meal = details.meal;
    final decision = details.advisorDecision;

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
        _InfoRow(
          label: 'Source',
          value: meal.isSynced ? 'Nightscout' : 'Local',
        ),
        _InfoRow(
          label: 'Meal advisor decision',
          value: decision?.result ?? '-',
        ),
        if (decision != null) ...[
          _InfoRow(
            label: 'Initial wait',
            value: '${decision.initialWaitTime} min',
          ),
          _InfoRow(label: 'Final wait', value: '${decision.finalWaitTime} min'),
          _InfoRow(
            label: 'Decision reason',
            value: _fallback(decision.decisionReason),
          ),
        ],
        if (detailed) ...[
          _InfoRow(label: 'Meal id', value: meal.id.toString()),
          _InfoRow(
            label: 'Template id',
            value: meal.mealTemplateId?.toString() ?? '-',
          ),
          _InfoRow(
            label: 'Based on meal id',
            value: meal.basedOnMealId?.toString() ?? '-',
          ),
          _InfoRow(label: 'Synced', value: meal.isSynced ? 'yes' : 'no'),
        ],
      ],
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  final MealDetailsData details;

  const _IngredientsSection({required this.details});

  @override
  Widget build(BuildContext context) {
    return _SectionTile(
      title: 'Ingredients',
      initiallyExpanded: true,
      children: [
        for (final ingredient in details.ingredients)
          _IngredientTile(ingredient: ingredient),
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

    return ListTile(
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
          ? const Icon(Icons.chevron_right)
          : Tooltip(
              message:
                  'Ten posiłek używa historycznych wartości; link do aktualnego składnika jest nieaktywny.',
              child: Icon(Icons.link_off, color: scheme.error),
            ),
      onTap: canOpenIngredient
          ? () => context.router.push(
              IngredientRoute(ingredientId: ingredient.ingredientId),
            )
          : null,
    );
  }
}

class _NutrientAnalysisSection extends StatelessWidget {
  final MealDetailsData details;

  const _NutrientAnalysisSection({required this.details});

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
      title: 'Nutrient analysis',
      children: [
        NutrientSummaryChart(macros: macros),
        const SizedBox(height: 8),
        _ContributionBreakdown(details: details),
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
                'carbs ${_share(ingredient.consumedCarbsContribution, totalCarbs)} • fat ${_share(ingredient.consumedFatContribution, totalFat)} • kcal ${_share(ingredient.consumedCaloriesContribution, totalCalories)}',
          ),
      ],
    );
  }
}

class _GlucoseAnalysisSection extends ConsumerWidget {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final DateTime? selectedTimestamp;

  const _GlucoseAnalysisSection({
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

    final stats = analysis.glucoseStats;
    return _SectionTile(
      title: 'Glucose analysis',
      initiallyExpanded: true,
      children: [
        MealGlucoseChart(
          analysis: analysis,
          selectedTimestamp: selectedTimestamp,
          onTimestampSelected: (timestamp) {
            ref
                .read(mealDetailsControllerProvider(details.meal.id).notifier)
                .selectTimestamp(timestamp);
          },
        ),
        _CrosshairDetailsCard(
          analysis: analysis,
          selectedTimestamp: selectedTimestamp,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricPill(
              label: 'Avg',
              value: _mgdl(stats.averageGlucose?.round()),
            ),
            _MetricPill(label: 'Min', value: _mgdl(stats.minGlucose)),
            _MetricPill(label: 'Max', value: _mgdl(stats.maxGlucose)),
            _MetricPill(label: 'Delta', value: _signedMgdl(stats.glucoseDelta)),
            _MetricPill(
              label: 'Rate',
              value: stats.glucoseRateMgDlPerMinute == null
                  ? '-'
                  : '${stats.glucoseRateMgDlPerMinute!.toStringAsFixed(2)} mg/dL/min',
            ),
            _MetricPill(
              label: 'Meal response',
              value: analysis.responseScore.score == null
                  ? analysis.responseScore.label
                  : '${analysis.responseScore.label} ${analysis.responseScore.score}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final flag in analysis.behaviorFlags)
          _InfoRow(label: flag.label, value: flag.reason),
      ],
    );
  }
}

class _CobIobSection extends ConsumerWidget {
  final int mealId;
  final MealAnalysisData analysis;
  final DateTime? selectedTimestamp;

  const _CobIobSection({
    required this.mealId,
    required this.analysis,
    required this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionTile(
      title: 'COB / IOB',
      children: [
        MealCobIobChart(
          analysis: analysis,
          selectedTimestamp: selectedTimestamp,
          onTimestampSelected: (timestamp) {
            ref
                .read(mealDetailsControllerProvider(mealId).notifier)
                .selectTimestamp(timestamp);
          },
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendItem(color: Colors.green, label: 'COB'),
            _LegendItem(color: Colors.blue, label: 'IOB'),
          ],
        ),
        const SizedBox(height: 8),
        _InfoRow(label: 'Latest COB', value: _grams(analysis.latestCob)),
        _InfoRow(label: 'Latest IOB', value: _units(analysis.latestIob)),
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

class _CrosshairDetailsCard extends StatelessWidget {
  final MealAnalysisData analysis;
  final DateTime? selectedTimestamp;

  const _CrosshairDetailsCard({
    required this.analysis,
    required this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedTimestamp;
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final glucose = _nearestByDate(
      analysis.glucoseReadings,
      selected,
      (item) => item.date,
    );
    final status = _nearestByDate(
      analysis.deviceStatuses,
      selected,
      (item) => item.date,
    );
    final activeEvents = analysis.timelineEvents.where((event) {
      return event.timestamp.difference(selected).inMinutes.abs() <= 5;
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MetricPill(label: 'Selected', value: _time(selected)),
          _MetricPill(label: 'Glucose', value: _mgdl(glucose?.sgv)),
          _MetricPill(label: 'COB', value: _grams(status?.cob)),
          _MetricPill(label: 'IOB', value: _units(status?.iob)),
          _MetricPill(
            label: 'Events',
            value: activeEvents.isEmpty
                ? '-'
                : activeEvents.map((event) => event.label).join(', '),
          ),
        ],
      ),
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

class _DebugSection extends StatelessWidget {
  final MealDetailsData details;
  final MealAnalysisData? analysis;

  const _DebugSection({required this.details, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return _SectionTile(
      title: 'Debug data',
      children: [
        _InfoRow(label: 'Meal id', value: details.meal.id.toString()),
        _InfoRow(
          label: 'Ingredients',
          value: details.ingredients.length.toString(),
        ),
        _InfoRow(
          label: 'Status history',
          value: details.statusHistory.length.toString(),
        ),
        _InfoRow(
          label: 'Treatments',
          value: analysis?.treatments.length.toString() ?? '-',
        ),
        _InfoRow(
          label: 'Device status',
          value: analysis?.deviceStatuses.length.toString() ?? '-',
        ),
        _InfoRow(
          label: 'Glucose readings',
          value: analysis?.glucoseReadings.length.toString() ?? '-',
        ),
      ],
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

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: scheme.primaryContainer,
      labelStyle: TextStyle(color: scheme.onPrimaryContainer),
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

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
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
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
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

String _signedMgdl(int? value) {
  if (value == null) return '-';
  final prefix = value > 0 ? '+' : '';
  return '$prefix$value mg/dL';
}

String _grams(double? value) => value == null ? '-' : '${_number(value)}g';

String _units(double? value) =>
    value == null ? '-' : '${value.toStringAsFixed(2)}U';

String _percent(double? value) => value == null ? '-' : '${value.round()}%';

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

T? _nearestByDate<T>(
  Iterable<T> items,
  DateTime target,
  DateTime Function(T item) dateOf,
) {
  T? nearest;
  int? bestDistance;
  for (final item in items) {
    final distance = dateOf(item).difference(target).inMilliseconds.abs();
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      nearest = item;
    }
  }
  return nearest;
}
