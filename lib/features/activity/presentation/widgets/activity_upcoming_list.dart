import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/planning/is_upcoming_activity_occurrence.dart';
import '../../../../common/presentation/widgets/activity_upcoming_sessions_view.dart';
import '../../../../common/widgets/date_time_picker.dart';
import '../../../../common/widgets/responsive_bottom_sheet.dart';
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import '../../data/mappers/activity_draft_mapper.dart';
import '../../data/providers/activity_provider.dart';
import '../../data/services/activity_schedule_service.dart';
import '../../data/services/save_activity_action.dart';
import 'activity_occurrence_card.dart';

class ActivityUpcomingList extends ConsumerStatefulWidget {
  const ActivityUpcomingList({super.key});
  @override
  ConsumerState<ActivityUpcomingList> createState() =>
      ActivityUpcomingListState();
}

class ActivityUpcomingListState extends ConsumerState<ActivityUpcomingList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        perform(() => ref.read(activityScheduleServiceProvider).refresh());
      }
    });
  }

  Future<void> perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.activityScheduleSaveFailed)),
        );
      }
    }
  }

  Future<void> recordHistory(ActivityOccurrenceData row) => perform(() async {
    final activity = await ref.read(
      getActivityByIdProvider(row.activityId).future,
    );
    if (!mounted || activity == null) return;
    final action = await showResponsiveBottomSheet<DashboardActivityAction>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DashboardActivitySheet(
        initialActivity: activity.toDraft(),
        initialMode: ActivityEntryMode.historical,
        initialStart: DateTime.fromMillisecondsSinceEpoch(row.startedAt),
        initialDuration: row.durationMinutes,
        lockMode: true,
      ),
    );
    if (action == null || !mounted) return;
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      final current = await (db.select(
        db.activityOccurrence,
      )..where((r) => r.id.equals(row.id))).getSingleOrNull();
      if (current == null || !['missed', 'pending'].contains(current.status)) {
        return;
      }
      final logId = await saveActivityAction(ref, action);
      await (db.update(
        db.activityOccurrence,
      )..where((r) => r.id.equals(row.id))).write(
        ActivityOccurrenceCompanion(
          status: const Value('recorded'),
          activityLogId: Value(logId),
        ),
      );
    });
  });

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(activityOccurrencesProvider);
    final reschedules = {
      for (final row
          in ref.watch(activityReschedulesProvider).value ??
              <ActivityOccurrenceRescheduleData>[])
        row.occurrenceId: row,
    };
    final activities = ref.watch(activityListStreamProvider);
    final names = {
      for (final activity in activities.value ?? []) activity.id: activity.name,
    };
    final service = ref.read(activityScheduleServiceProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.lang.activityScheduleSaveFailed)),
      data: (rows) {
        final now = clock.now();
        final visible = rows
            .where(
              (row) => isUpcomingActivityOccurrence(
                status: row.status,
                startedAt: row.startedAt,
                now: now,
              ),
            )
            .toList();
        return ActivityUpcomingSessionsView(
          emptyLabel: context.lang.activityUpcomingEmpty,
          entries: visible
              .map(
                (row) => ActivityOccurrenceCard(
                  row: row,
                  originalStartedAt: reschedules[row.id]?.originalStartedAt,
                  name: names[row.activityId] ?? context.lang.activityTitle,
                  onConfirm: () => perform(() async {
                    await service.confirm(
                      row.id,
                      expectedStartedAt: row.startedAt,
                      expectedRevision:
                          reschedules[row.id]?.notificationRevision ?? 0,
                    );
                  }),
                  onSkip: () => perform(
                    () => service.skip(
                      row.id,
                      expectedStartedAt: row.startedAt,
                      expectedRevision:
                          reschedules[row.id]?.notificationRevision ?? 0,
                    ),
                  ),
                  onMove: () => perform(() async {
                    final date = await showDateTimePicker(
                      context: context,
                      initialDate: DateTime.fromMillisecondsSinceEpoch(
                        row.startedAt,
                      ),
                    );
                    if (date != null) {
                      await service.move(
                        row.id,
                        date,
                        expectedStartedAt: row.startedAt,
                        expectedRevision:
                            reschedules[row.id]?.notificationRevision ?? 0,
                      );
                    }
                  }),
                  onHistory: () => recordHistory(row),
                  onDelete:
                      row.startedAt > now.millisecondsSinceEpoch ||
                          row.activityLogId == null
                      ? () => perform(
                          () => service.removeOccurrence(
                            row.id,
                            expectedStartedAt: row.startedAt,
                            expectedRevision:
                                reschedules[row.id]?.notificationRevision ?? 0,
                          ),
                        )
                      : null,
                ),
              )
              .toList(),
        );
      },
    );
  }
}
