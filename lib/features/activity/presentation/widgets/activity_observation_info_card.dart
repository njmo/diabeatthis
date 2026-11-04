import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/information_button.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../utils/activity_log_formatters.dart';

class ActivityObservationInfoCard extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  const ActivityObservationInfoCard({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) => SectionSurface(
    child: Row(
      children: [
        Icon(
          Icons.schedule_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.lang.activityObservationWindow,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatActivityLogTime(analysis.activityEnd)}–${formatActivityLogTime(analysis.chartEnd)}',
              ),
            ],
          ),
        ),
        InformationButton(
          title: context.lang.activityObservationWindow,
          message: context.lang.activityPostWindow,
          icon: Icons.help_outline_rounded,
        ),
      ],
    ),
  );
}
