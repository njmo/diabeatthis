import 'package:flutter/material.dart';

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

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ActivityLogStatusChip(active: isActive),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActivityLogMetaPill(
                    icon: Icons.calendar_today,
                    text: _formatDate(startedAt),
                  ),
                  ActivityLogMetaPill(
                    icon: Icons.access_time,
                    text: _formatTimeRange(startedAt, endedAt),
                  ),
                  ActivityLogMetaPill(
                    icon: Icons.timer,
                    text: _formatDuration(startedAt, endedAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatTimeRange(DateTime startedAt, DateTime? endedAt) {
    final end = endedAt == null ? 'teraz' : _formatTime(endedAt);
    return '${_formatTime(startedAt)} - $end';
  }

  static String _formatDuration(DateTime startedAt, DateTime? endedAt) {
    if (endedAt == null) {
      return 'W trakcie';
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
