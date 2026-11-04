import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_metric_section.dart';
import '../../../../common/widgets/detail_metric_tile.dart';
import '../../../../common/widgets/detail_section_card.dart';
import '../../common/widgets/activity_intensity_field.dart';
import '../../data/models/activity_log_details_data.dart';
import '../utils/activity_log_formatters.dart';

class ActivityLogInformation extends StatelessWidget {
  final ActivityLogDetailsData log;
  const ActivityLogInformation({super.key, required this.log});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailSectionCard(
          title: context.lang.activityTimeTitle,
          children: [
            DetailInfoRow(
              icon: Icons.play_arrow,
              label: context.lang.activityStartLabel,
              value: formatActivityLogDateTime(log.startedAt),
            ),
            DetailInfoRow(
              icon: Icons.stop,
              label: context.lang.activityEndLabel,
              value: log.endedAt == null
                  ? context.lang.activityInProgress
                  : formatActivityLogDateTime(log.endedAt!),
            ),
            DetailInfoRow(
              icon: Icons.timer,
              label: context.lang.activityDurationLabel,
              value: formatActivityDuration(context.lang, log.duration),
            ),
            DetailInfoRow(
              icon: Icons.schedule,
              label: context.lang.activityPlannedDurationLabel,
              value: formatActivityMinutes(context.lang, log.durationMinutes),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DetailMetricSection(
          title: context.lang.activityRecordedSettings,
          icon: Icons.vaccines_rounded,
          metrics: [
            DetailMetricTile(
              icon: Icons.schedule,
              label: context.lang.activityPreMealSensitivityLabel,
              value: context.lang.activityDosePercent(log.percentagePre),
            ),
            DetailMetricTile(
              icon: Icons.sports_score,
              label: context.lang.activityAfterWorkoutLabel,
              value: context.lang.activityDosePercent(log.percentagePost),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DetailSectionCard(
          title: context.lang.activityDetailsTitle,
          children: [
            ...[
              DetailInfoRow(
                icon: Icons.speed,
                label: context.lang.activityIntensityLabel,
                value: ActivityIntensityField.label(
                  context.lang,
                  log.intensity,
                ),
              ),
              DetailInfoRow(
                icon: Icons.notes,
                label: context.lang.activityNotesLabel,
                value: log.notes?.trim().isNotEmpty == true ? log.notes! : '—',
              ),
            ],
            DetailInfoRow(
              icon: Icons.sync,
              label: context.lang.activitySyncLabel,
              value: log.isSynced
                  ? context.lang.activitySynced
                  : context.lang.activityLocalChanges,
              valueColor: log.isSynced ? scheme.primary : scheme.error,
            ),
            DetailInfoRow(
              icon: Icons.update,
              label: context.lang.activityLastChangedLabel,
              value: formatActivityLogDateTime(log.updatedAt),
            ),
          ],
        ),
      ],
    );
  }
}
