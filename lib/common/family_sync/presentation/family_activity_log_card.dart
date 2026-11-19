import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/activity/data/models/activity_log_summary_data.dart';
import '../../../features/dashboard/data/providers/time_now_provider.dart';
import '../../../features/dashboard/presentation/widgets/dashboard_activity_card.dart';
import '../../l10n/language.dart';
import '../../presentation/widgets/activity_log_card.dart';

/// Cloud adapter; rendering is shared with the child's local history.
class FamilyActivityLogCard extends ConsumerWidget {
  const FamilyActivityLogCard({
    super.key,
    required this.payload,
    required this.name,
    this.durationMinutes,
    this.onOpen,
  });
  final Map payload;
  final String name;
  final int? durationMinutes;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (payload['ended_at'] == null) {
      return DashboardActivityCard(
        activity: ActivityLogSummaryData(
          id: payload['id'] as int,
          activityName: name,
          activityId: payload['activity_id'] as int,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            payload['started_at'] as int,
          ),
          endedAt: null,
          durationMinutes: durationMinutes,
        ),
        now: ref.watch(timeNowProvider).value ?? DateTime.now(),
        allowLocalActions: false,
        trailing: onOpen == null
            ? null
            : IconButton(
                tooltip: context.lang.activityDetailsTitle,
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: onOpen,
              ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            DateFormat.yMd(context.lang.localeName).format(
              DateTime.fromMillisecondsSinceEpoch(
                payload['started_at'] as int,
              ).toLocal(),
            ),
          ),
        ),
        ActivityLogCard(
          name: name,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            payload['started_at'] as int,
          ),
          endedAt: payload['ended_at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(payload['ended_at'] as int),
          onTap: onOpen,
          notes: payload['notes'] as String?,
        ),
      ],
    );
  }
}
