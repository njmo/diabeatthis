import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../../activity/presentation/widgets/activity_summary_action.dart';

class DashboardCompletedActivityDetails extends StatelessWidget {
  const DashboardCompletedActivityDetails({super.key, required this.activity});
  final ActivityLogSummaryData activity;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.activityName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          context.lang.activitySummaryReady,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActivitySummaryAction(
          activityLogId: activity.id,
          summarized: false,
          intensity: activity.intensity,
          notes: activity.notes,
          compact: true,
          emphasized: true,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= 240 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 16
              ? Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 8),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 4), actions],
                ),
        ),
      ],
    );
  }
}
