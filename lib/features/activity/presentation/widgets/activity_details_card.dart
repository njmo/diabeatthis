import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_section_card.dart';

class ActivityDetailsCard extends StatelessWidget {
  final String name;
  final int percentagePre;
  final int percentagePost;
  final int? durationMinutes;

  const ActivityDetailsCard({
    super.key,
    required this.name,
    required this.percentagePre,
    required this.percentagePost,
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: name,
      children: [
        DetailInfoRow(
          icon: Icons.schedule,
          label: context.lang.activityPreMealSensitivityLabel,
          value: context.lang.activityPercentLess(percentagePre),
        ),
        DetailInfoRow(
          icon: Icons.sports_score,
          label: context.lang.activityPostWorkoutSensitivityLabel,
          value: context.lang.activityPercentLess(percentagePost),
        ),
        DetailInfoRow(
          icon: Icons.timer,
          label: context.lang.activityPlannedDurationLabel,
          value: _formatDuration(context, durationMinutes),
        ),
      ],
    );
  }

  static String _formatDuration(BuildContext context, int? minutes) {
    if (minutes == null) {
      return context.lang.activityManualStop;
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
