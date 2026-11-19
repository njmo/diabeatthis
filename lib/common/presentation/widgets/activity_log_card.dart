import 'package:flutter/material.dart';

import '../../../features/activity/presentation/utils/activity_log_formatters.dart';
import '../../../features/activity/presentation/widgets/activity_log_meta_pill.dart';
import '../../../features/activity/presentation/widgets/activity_log_status_chip.dart';
import '../../activity/activity_session_state.dart';
import '../../l10n/language.dart';
import '../../widgets/date_time_boundary_builder.dart';
import '../../widgets/history_entry_row.dart';

class ActivityLogCard extends StatelessWidget {
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final VoidCallback? onTap;
  final int? durationMinutes;
  final String? notes;

  const ActivityLogCard({
    super.key,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.onTap,
    this.durationMinutes,
    this.notes,
  });

  @override
  Widget build(BuildContext context) => DateTimeBoundaryBuilder(
    at: endedAt == null ? startedAt : null,
    builder: (context, now) {
      final state = activitySessionState(
        startedAt: startedAt,
        endedAt: endedAt,
        now: now,
      );
      final language = context.lang;
      final start = formatActivityLogTime(startedAt.toLocal());
      final range = state == ActivitySessionState.planned
          ? start
          : '$start - ${endedAt == null ? language.relativeTimeNow : formatActivityLogTime(endedAt!.toLocal())}';
      return HistoryEntryRow(
        name: name,
        onTap: onTap,
        details: notes?.trim().isNotEmpty == true ? Text(notes!) : null,
        metadata: [
          ActivityLogStatusChip(state: state),
          ActivityLogMetaPill(icon: Icons.access_time, text: range),
          ActivityLogMetaPill(
            icon: Icons.timer,
            text: formatActivitySessionDuration(
              language,
              startedAt: startedAt,
              endedAt: endedAt,
              plannedMinutes: durationMinutes,
              now: now,
            ),
          ),
        ],
      );
    },
  );
}
