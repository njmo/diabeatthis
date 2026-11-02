import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/history_entry_row.dart';
import 'activity_log_meta_pill.dart';
import 'activity_log_status_chip.dart';

class ActivityLogCard extends StatelessWidget {
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final VoidCallback onTap;

  const ActivityLogCard({
    super.key,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = endedAt == null;

    return HistoryEntryRow(
      name: name,
      onTap: onTap,
      metadata: [
        ActivityLogStatusChip(active: isActive),
        ActivityLogMetaPill(
          icon: Icons.access_time,
          text: _formatTimeRange(startedAt.toLocal(), endedAt?.toLocal()),
        ),
        ActivityLogMetaPill(
          icon: Icons.timer,
          text: _formatDuration(startedAt, endedAt),
        ),
      ],
    );
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatTimeRange(DateTime startedAt, DateTime? endedAt) {
    final end = endedAt == null ? lang.relativeTimeNow : _formatTime(endedAt);
    return '${_formatTime(startedAt)} - $end';
  }

  static String _formatDuration(DateTime startedAt, DateTime? endedAt) {
    if (endedAt == null) {
      return lang.activityInProgress;
    }

    final duration = endedAt.difference(startedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    return '${hours}h ${minutes.toString().padLeft(2, '0')} min';
  }
}
