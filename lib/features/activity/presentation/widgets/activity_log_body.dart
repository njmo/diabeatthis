import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/activity/activity_session_state.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/details/activity_log_preview_controller.dart';
import '../../../../common/widgets/date_time_boundary_builder.dart';
import '../../../../common/widgets/detail_identity_header.dart';
import '../../../../common/widgets/detail_metadata_row.dart';
import '../../../../common/widgets/swipeable_cards.dart';
import '../../common/widgets/activity_intensity_field.dart';
import '../models/activity_log_page_state.dart';
import '../utils/activity_log_formatters.dart';
import 'activity_after_section.dart';
import 'activity_before_section.dart';
import 'activity_glucose_overview.dart';
import 'activity_log_analysis_section.dart';
import 'activity_log_information.dart';

class ActivityLogBody extends HookWidget {
  final ActivityLogPageState state;
  final ValueChanged<DateTime> onTimestampSelected;
  const ActivityLogBody({
    super.key,
    required this.state,
    required this.onTimestampSelected,
    this.presentation,
  });
  final ActivityLogPreviewController? presentation;
  ActivityLogBody.controlled({
    super.key,
    required ActivityLogPreviewController controller,
    required this.onTimestampSelected,
  }) : state = controller.state,
       presentation = controller;

  @override
  Widget build(BuildContext context) {
    final source = presentation ?? PatientActivityLogPreviewController(state);
    final controller = useTabController(
      initialLength: source.showAnalysis ? 5 : 1,
      keys: [source.showAnalysis],
    );
    final log = state.data;
    final lang = context.lang;
    final date = DateFormat(
      'd MMMM yyyy · HH:mm',
      lang.localeName,
    ).format(log.startedAt);
    Widget analysisTab(Widget Function() builder) {
      if (log.endedAt == null) {
        return Text(lang.activityAnalysisAvailableAfterFinish);
      }
      return state.analysis.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(lang.activityError(error)),
        data: (analysis) =>
            analysis == null ? Text(lang.activityMissingData) : builder(),
      );
    }

    return DateTimeBoundaryBuilder(
      at: log.endedAt == null ? log.startedAt : null,
      builder: (context, now) => SwipeableCards(
        key: ValueKey(log.id),
        controller: controller,
        showPageControls: false,
        header: DetailIdentityHeader(
          title: log.activityName,
          titleAction: !source.canUseLocalActions
              ? null
              : TextButton.icon(
                  icon: const Icon(Icons.history_rounded),
                  label: Text(lang.activityHistoryShort),
                  onPressed: () => context.router.push(
                    routes.ActivityRoute(activityId: log.activityId),
                  ),
                ),
          status: activitySessionStateLabel(
            lang,
            activitySessionState(
              startedAt: log.startedAt,
              endedAt: log.endedAt,
              now: now,
            ),
          ),
          dateLabel: date,
          dateIcon: Icons.calendar_today_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailMetadataRow(
                icon: Icons.timer_outlined,
                label:
                    '${lang.activityDurationLabel}: ${formatActivitySessionDuration(lang, startedAt: log.startedAt, endedAt: log.endedAt, plannedMinutes: log.durationMinutes, now: now)}',
              ),
              const SizedBox(height: 8),
              DetailMetadataRow(
                icon: Icons.speed_rounded,
                label:
                    '${lang.activityIntensityLabel}: ${log.intensity == null ? lang.activityIntensityNotRecorded : ActivityIntensityField.label(lang, log.intensity)}',
              ),
            ],
          ),
        ),
        labels: [
          if (source.showAnalysis) ...[
            lang.activityTabSummary,
            lang.activityTabBefore,
            lang.activityTabCourse,
            lang.activityTabAfter,
          ],
          lang.activityDetailsTitle,
        ],
        children: [
          if (source.showAnalysis) ...[
            analysisTab(
              () => ActivityGlucoseOverview(
                analysis: state.analysis.value!,
                log: log,
              ),
            ),
            analysisTab(
              () => ActivityBeforeSection(
                analysis: state.analysis.value!,
                log: log,
                showRecordedSettings: source.showRecordedSettings,
              ),
            ),
            analysisTab(
              () => ActivityLogAnalysisSection(
                analysis: state.analysis.value!,
                lowTreatments: state.lowTreatments,
                selectedTimestamp: state.selectedTimestamp,
                onTimestampSelected: onTimestampSelected,
              ),
            ),
            analysisTab(
              () => ActivityAfterSection(
                analysis: state.analysis.value!,
                hasLocalMealContext: source.canUseLocalActions,
              ),
            ),
          ],
          ActivityLogInformation(
            log: log,
            showRecordedSettings: source.showRecordedSettings,
          ),
        ],
      ),
    );
  }
}
