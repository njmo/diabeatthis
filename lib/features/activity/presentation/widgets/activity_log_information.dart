import 'package:flutter/material.dart';

import '../../../../common/activity/activity_session_state.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_boundary_builder.dart';
import '../../../../common/widgets/detail_metric_section.dart';
import '../../../../common/widgets/detail_metric_tile.dart';
import '../../../../common/widgets/detail_section_card.dart';
import '../../common/widgets/activity_intensity_field.dart';
import '../../data/models/activity_log_details_data.dart';
import '../utils/activity_log_formatters.dart';

class ActivityLogInformation extends StatelessWidget {
  final ActivityLogDetailsData log;
  const ActivityLogInformation({
    super.key,
    required this.log,
    this.showRecordedSettings = true,
  });
  final bool showRecordedSettings;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DateTimeBoundaryBuilder(
      at: log.endedAt == null ? log.startedAt : null,
      builder: (context, now) => Column(
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
                    ? (activitySessionState(
                                startedAt: log.startedAt,
                                endedAt: log.endedAt,
                                now: now,
                              ) ==
                              ActivitySessionState.planned
                          ? context.lang.activitySchedulePlanned
                          : context.lang.activityInProgress)
                    : formatActivityLogDateTime(log.endedAt!),
              ),
              DetailInfoRow(
                icon: Icons.timer,
                label: context.lang.activityDurationLabel,
                value: formatActivitySessionDuration(
                  context.lang,
                  startedAt: log.startedAt,
                  endedAt: log.endedAt,
                  plannedMinutes: log.durationMinutes,
                  now: now,
                ),
              ),
              if (showRecordedSettings)
                DetailInfoRow(
                  icon: Icons.schedule,
                  label: context.lang.activityPlannedDurationLabel,
                  value: formatActivityMinutes(
                    context.lang,
                    log.durationMinutes,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (showRecordedSettings)
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
                  value: log.notes?.trim().isNotEmpty == true
                      ? log.notes!
                      : '—',
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
      ),
    );
  }
}
