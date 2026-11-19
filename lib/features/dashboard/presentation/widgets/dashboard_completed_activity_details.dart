import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../../activity/presentation/widgets/activity_summary_action.dart';

class DashboardCompletedActivityDetails extends StatelessWidget {
  const DashboardCompletedActivityDetails({
    super.key,
    required this.activity,
    this.allowLocalActions = true,
  });
  final ActivityLogSummaryData activity;
  final bool allowLocalActions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          activity.activityName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: numColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          context.lang.activitySummaryReady,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: mutedColor,
          ),
        ),
      ],
    );
    if (!allowLocalActions) return heading;
    final actions = ActivitySummaryAction(
      activityLogId: activity.id,
      summarized: false,
      intensity: activity.intensity,
      notes: activity.notes,
      compact: true,
      emphasized: true,
    );
    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: 8),
        actions,
      ],
    );
  }
}
