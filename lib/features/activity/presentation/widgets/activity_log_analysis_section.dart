import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_section_card.dart';
import '../../../meals/data/models/meal_details_data.dart';
import '../../data/models/activity_log_analysis_data.dart';
import 'activity_chart_legend_item.dart';
import 'activity_corrections_card.dart';
import 'activity_glucose_chart.dart';
import 'activity_low_treatments_section.dart';
import 'activity_session_events.dart';

class ActivityLogAnalysisSection extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  final List<MealLowTreatmentDetailsData> lowTreatments;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime>? onTimestampSelected;

  const ActivityLogAnalysisSection({
    super.key,
    required this.analysis,
    this.lowTreatments = const [],
    this.selectedTimestamp,
    this.onTimestampSelected,
  });

  @override
  Widget build(BuildContext context) {

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
                  const ActivityChartLegendItem(
                    color: Colors.green,
                    label: '70-180',
                  ),
                  const ActivityChartLegendItem(
                    color: Colors.amber,
                    label: '180-250',
                  ),
                  const ActivityChartLegendItem(
                    color: Colors.red,
                    label: '<70 / >250',
                  ),
                  ActivityChartLegendItem(
                    color: Colors.teal,
                    label: context.lang.activityLegendActivity,
                  ),
                  ActivityChartLegendItem(
                    color: Colors.blue,
                    label: context.lang.historyTemporaryTarget,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ActivityCorrectionsCard(analysis: analysis),
        const SizedBox(height: 16),
        ActivitySessionEvents(title: context.lang.activityDuringEvents,
          treatments: analysis.chartTreatments, start: analysis.activityStart, end: analysis.activityEnd),
        const SizedBox(height: 16),
        ActivityLowTreatmentsSection(lowTreatments: lowTreatments, activityStart: analysis.activityStart),
      ],
    );
  }
}
