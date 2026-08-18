import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_details_data.dart';
import '../../models/meal_metric_view_data.dart';
import '../../models/meal_page_state.dart';
import '../../utils/meal_extended_carbs_warning.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';
import 'meal_metric_components.dart';

class MealHeader extends StatelessWidget {
  final MealPageState state;

  const MealHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final summary = details.preferredSummarySnapshot;
    final stats = state.analysis?.glucoseStats;
    final metrics = [
      MealMetricTileData(
        icon: Icons.monitor_heart_outlined,
        label: lang.mealPeakGlucoseLabel,
        value: formatMgdl(stats?.peakGlucose),
      ),
      MealMetricTileData(
        icon: Icons.timer_outlined,
        label: lang.mealTimeToPeakLabel,
        value: formatDurationOffset(stats?.timeToPeak),
      ),
      MealMetricTileData(
        icon: Icons.timeline,
        label: lang.mealAverageGlucoseLabel,
        value: formatMgdl(stats?.averageGlucose?.round()),
      ),
      MealMetricTileData(
        icon: Icons.vaccines_outlined,
        label: lang.mealTotalInsulinLabel,
        value: formatUnits(
          state.analysis?.totalInsulinUnits ?? details.totalInsulinUnits,
        ),
      ),
      MealMetricTileData(
        icon: Icons.grain,
        label: lang.mealCarbsLabel,
        value: formatGrams(summary?.totalCarbsG),
      ),
      if (details.hasLowTreatments)
        MealMetricTileData(
          icon: Icons.bloodtype_outlined,
          label: lang.mealLowTreatmentDelay(
            formatDelayAfterMeal(details.firstLowTreatmentDelay),
          ),
          value: formatGrams(details.lowTreatmentNetCarbsG),
        ),
      MealMetricTileData(
        icon: Icons.more_time,
        label: lang.mealExtendedCarbsLabel,
        value: formatGrams(
          details.advisorDecision?.extendedCarbsGrams.toDouble(),
        ),
      ),
      if (details.hasAddOn)
        MealMetricTileData(
          icon: Icons.add_circle_outline,
          label: lang.mealAddOnLabel,
          value: formatSignedGrams(details.addOnNetCarbsG),
        ),
      MealMetricTileData(
        icon: Icons.check_circle_outline,
        label: lang.mealTimeInRangeLabel,
        value: formatPercent(stats?.timeInRangePercent),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MealAnalysisProgressSummary(state: state),
        const SizedBox(height: 12),
        MealMetricGrid(wideColumns: 3, metrics: metrics),
      ],
    );
  }
}

class MealAnalysisProgressSummary extends StatelessWidget {
  final MealPageState state;

  const MealAnalysisProgressSummary({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final analysis = state.analysis;
    final chips = [if (details.isCopied) const HeaderStatusChip.copied()];
    if (details.hasLowTreatments) {
      chips.add(const HeaderStatusChip.lowTreatment());
    }
    if (!details.meal.isEaten) {
      chips.add(
        HeaderStatusChip(
          icon: mealStatusIcon(details.meal.status),
          label: mealStatusLabel(details.meal.status),
        ),
      );
      if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
      return MealHeaderStatusRow(chips: chips);
    }
    if (analysis == null) {
      chips.add(
        const HeaderStatusChip(
          icon: Icons.pending_actions,
          label: '',
          type: HeaderStatusChipType.analysisPending,
        ),
      );
      if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
      return MealHeaderStatusRow(chips: chips);
    }
    if (!analysis.hasFullGlucoseWindow) {
      chips.add(
        HeaderStatusChip(
          icon: Icons.hourglass_top,
          label: '',
          detail: mealTime(analysis.expectedChartEnd),
          type: HeaderStatusChipType.analysisInProgress,
        ),
      );
      if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
      return MealHeaderStatusRow(chips: chips);
    }
    chips.add(
      HeaderStatusChip(
        icon: Icons.check_circle,
        label: '',
        detail: analysis.postMealWindow.inMinutes.toString(),
        type: HeaderStatusChipType.analysisReady,
      ),
    );
    if (shouldShowMissingExtendedCarbsWarning(
      details: details,
      analysis: analysis,
    )) {
      chips.add(const HeaderStatusChip.missingExtendedCarbs());
    }
    if (_shouldShowWaitTimeIgnoredChip(details.advisorDecision)) {
      chips.add(const HeaderStatusChip.waitTimeIgnored());
    }
    if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
    return MealHeaderStatusRow(chips: chips);
  }
}

bool _shouldShowWaitTimeIgnoredChip(MealAdvisorDecisionData? decision) {
  return decision?.result == 'bolused-waiting' &&
      decision?.waitTimeIgnored == true;
}

class MealHeaderStatusRow extends StatelessWidget {
  final List<HeaderStatusChip> chips;

  const MealHeaderStatusRow({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

class HeaderStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final HeaderStatusChipType? type;

  const HeaderStatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
    this.type,
  });

  const HeaderStatusChip.addOn({super.key})
    : icon = Icons.add_circle_outline,
      label = '',
      detail = null,
      type = HeaderStatusChipType.addOn;

  const HeaderStatusChip.lowTreatment({super.key})
    : icon = Icons.bloodtype_outlined,
      label = '',
      detail = null,
      type = HeaderStatusChipType.lowTreatment;

  const HeaderStatusChip.copied({super.key})
    : icon = Icons.content_copy,
      label = '',
      detail = null,
      type = HeaderStatusChipType.copied;

  const HeaderStatusChip.missingExtendedCarbs({super.key})
    : icon = Icons.warning_amber_rounded,
      label = '',
      detail = null,
      type = HeaderStatusChipType.missingExtendedCarbs;

  const HeaderStatusChip.waitTimeIgnored({super.key})
    : icon = Icons.fast_forward_outlined,
      label = '',
      detail = null,
      type = HeaderStatusChipType.waitTimeIgnored;

  @override
  Widget build(BuildContext context) {
    final text = _text(context.lang);
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      avatar: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: Text(text),
    );
  }

  String _text(AppLocalizations lang) {
    if (type == null) {
      return detail == null ? label : '$label • $detail';
    }
    return switch (type!) {
      HeaderStatusChipType.addOn => lang.mealHeaderAddOnChip,
      HeaderStatusChipType.lowTreatment => lang.mealHeaderLowTreatmentChip,
      HeaderStatusChipType.copied => lang.mealHeaderCopiedChip,
      HeaderStatusChipType.missingExtendedCarbs =>
        lang.mealHeaderMissingExtendedCarbsChip,
      HeaderStatusChipType.waitTimeIgnored =>
        lang.mealHeaderWaitTimeIgnoredChip,
      HeaderStatusChipType.analysisPending => lang.mealHeaderAnalysisPending,
      HeaderStatusChipType.analysisInProgress =>
        lang.mealHeaderAnalysisInProgress(detail ?? ''),
      HeaderStatusChipType.analysisReady => lang.mealHeaderAnalysisReady(
        int.tryParse(detail ?? '') ?? 0,
      ),
    };
  }
}

enum HeaderStatusChipType {
  addOn,
  lowTreatment,
  copied,
  missingExtendedCarbs,
  waitTimeIgnored,
  analysisPending,
  analysisInProgress,
  analysisReady,
}
