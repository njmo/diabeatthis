import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_metric_section.dart';
import '../../../../common/widgets/detail_metric_tile.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../../data/models/activity_session_summary.dart';

class ActivityCorrectionsCard extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  final bool afterActivity;
  const ActivityCorrectionsCard({super.key, required this.analysis, this.afterActivity = false});
  @override
  Widget build(BuildContext context) {
    final summary = ActivitySessionSummary(analysis);
    return DetailMetricSection(
      title: afterActivity ? context.lang.activityCorrectionsAfter : context.lang.activityCorrectionsDuring,
      icon: Icons.vaccines_rounded,
      metrics: [DetailMetricTile(icon: Icons.vaccines_rounded,
        label: context.lang.activityRecordedCorrections,
        value: summary.corrections(afterActivity: afterActivity).length.toString(),
        detail: '${summary.correctionUnits(afterActivity: afterActivity).toStringAsFixed(2)} U')],
      children: [Text(context.lang.activityCorrectionHint)],
    );
  }
}
