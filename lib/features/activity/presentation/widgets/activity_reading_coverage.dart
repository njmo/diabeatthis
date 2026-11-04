import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../data/models/activity_session_summary.dart';

class ActivityReadingCoverage extends StatelessWidget {
  final ActivitySessionSummary summary;
  const ActivityReadingCoverage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return SectionSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sensors_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.activityCollectedReadings(
                    summary.during.length.toString(),
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  lang.activityMeasurementCoverage(
                    summary.period.coveragePercent?.round().toString() ?? '0',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
