import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_metric_section.dart';
import '../../../../common/widgets/detail_metric_tile.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../../data/models/activity_log_details_data.dart';
import '../../data/models/activity_session_summary.dart';
import '../utils/activity_log_formatters.dart';
import 'activity_last_meal_card.dart';

class ActivityBeforeSection extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  final ActivityLogDetailsData log;
  const ActivityBeforeSection({super.key, required this.analysis, required this.log});
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final summary = ActivitySessionSummary(analysis);
    final status = analysis.deviceStatusAtStart;
    final fresh = summary.hasFreshDeviceStatus;
    final detail = status == null ? lang.activityMissingData :
      lang.activityReadingTime(formatActivityLogTime(status.date));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailMetricSection(title: lang.activityStartSectionTitle, icon: Icons.play_arrow_rounded,
        metrics: [
          DetailMetricTile(icon: Icons.vaccines_rounded, label: lang.activityActiveInsulinLabel,
            value: fresh && status!.hasIob ? status.iob.toStringAsFixed(2) : '—', unit: 'U', detail: detail),
          DetailMetricTile(icon: Icons.grain_rounded, label: lang.activityActiveCarbsLabel,
            value: fresh && status!.hasCob ? status.cob.toStringAsFixed(1) : '—', unit: 'g', detail: detail),
        ], children: [if (!fresh) Text(lang.activityStaleStatus)]),
      const SizedBox(height: 16),
      ActivityLastMealCard(analysis: analysis),
      const SizedBox(height: 16),
      DetailMetricSection(title: lang.activityRecordedTargets, icon: Icons.flag_rounded,
        metrics: [
          DetailMetricTile(icon: Icons.play_arrow_rounded, label: lang.activityTargetAtStart,
            value: summary.targetAtStart ? lang.activityTargetPresent : lang.activityTargetAbsent),
          DetailMetricTile(icon: Icons.history_rounded, label: lang.activityTargetBefore,
            value: summary.targetBefore ? lang.activityTargetPresent : lang.activityTargetAbsent),
        ], children: [Text(lang.activityTargetHint)]),
      const SizedBox(height: 16),
      SummaryDetailCard(title: lang.activityRecordedSettings, icon: Icons.tune_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${lang.activityPreMealSensitivityLabel}: ${lang.activityDosePercent(log.percentagePre)}'),
          const SizedBox(height: 8), Text(lang.activitySettingsHint),
        ])),
    ]);
  }
}
