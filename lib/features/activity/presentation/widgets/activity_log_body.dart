import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
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
  });
  @override
  Widget build(BuildContext context) {
    final controller = useTabController(initialLength: 5);
    final log = state.data;
    final lang = context.lang;
    final date = DateFormat(
      'd MMMM yyyy · HH:mm',
      lang.localeName,
    ).format(log.startedAt);
    Widget analysisTab(Widget Function() builder) {
      if (log.isActive) return Text(lang.activityAnalysisAvailableAfterFinish);
      return state.analysis.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(lang.activityError(error)),
        data: (analysis) =>
            analysis == null ? Text(lang.activityMissingData) : builder(),
      );
    }

    return SwipeableCards(
      key: ValueKey(log.id),
      controller: controller,
      showPageControls: false,
      header: DetailIdentityHeader(
        title: log.activityName,
        titleAction: TextButton.icon(
          icon: const Icon(Icons.history_rounded),
          label: Text(lang.activityHistoryShort),
          onPressed: () => context.router.push(
            routes.ActivityRoute(activityId: log.activityId),
          ),
        ),
        status: log.isActive ? lang.activityActive : lang.activityFinished,
        dateLabel: date,
        dateIcon: Icons.calendar_today_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailMetadataRow(
              icon: Icons.timer_outlined,
              label:
                  '${lang.activityDurationLabel}: ${formatActivityDuration(lang, log.duration)}',
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
        lang.activityTabSummary,
        lang.activityTabBefore,
        lang.activityTabCourse,
        lang.activityTabAfter,
        lang.activityDetailsTitle,
      ],
      children: [
        analysisTab(
          () => ActivityGlucoseOverview(
            analysis: state.analysis.value!,
            log: log,
          ),
        ),
        analysisTab(
          () =>
              ActivityBeforeSection(analysis: state.analysis.value!, log: log),
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
          () => ActivityAfterSection(analysis: state.analysis.value!),
        ),
        ActivityLogInformation(log: log),
      ],
    );
  }
}
