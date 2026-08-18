import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/logger/logger.dart';
import '../../../activity/data/drafts/activity_log_draft.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../activity/presentation/widgets/activity_picker_sheet.dart';
import '../../data/providers/temporary_target_ui_provider.dart';
import '../../data/providers/time_now_provider.dart';

class DashboardStatusCard extends ConsumerWidget with Logging {
  const DashboardStatusCard({super.key});

  static const int activityTargetValue = 140;
  static const int mealTargetValue = 90;

  bool _isActivityTarget(TemporaryTarget target) =>
      target.targetTop == activityTargetValue;

  bool _isMealTarget(TemporaryTarget target) =>
      target.targetTop == mealTargetValue;

  bool _isTargetExpired(TemporaryTarget? target, DateTime now) {
    if (target == null) return true;

    final elapsed = now.difference(target.createdAt).inMinutes;
    return elapsed >= target.duration;
  }

  TemporaryTarget? _activeTarget(TemporaryTarget? target, DateTime now) {
    return _isTargetExpired(target, now) ? null : target;
  }

  int _elapsedMinutes(TemporaryTarget target, DateTime now) {
    final elapsed = now.difference(target.createdAt).inMinutes;
    return elapsed.clamp(0, target.duration);
  }

  int _activityElapsedMinutes(DateTime startedAt, DateTime now) {
    final minutes = now.difference(startedAt).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  int _remainingMinutes(DateTime endAt, DateTime now) {
    final seconds = endAt.difference(now).inSeconds;
    if (seconds <= 0) return 0;
    return (seconds / Duration.secondsPerMinute).ceil();
  }

  bool _isActivityPlanned(ActivityLogSummaryData activity, DateTime now) {
    return activity.startedAt.isAfter(now);
  }

  bool _isActivityLinkedToTarget(
    ActivityLogSummaryData? pendingActivity,
    TemporaryTarget target,
  ) {
    if (pendingActivity == null) return false;
    return pendingActivity.startedAt == target.createdAt;
  }

  String _activityName(ActivityLogSummaryData activity) {
    return activity.activityName;
  }

  int? _activityDurationMinutes(ActivityLogSummaryData activity) {
    return activity.durationMinutes;
  }

  String _targetSubtitle(TemporaryTarget target, DateTime now) {
    final elapsed = _elapsedMinutes(target, now);
    return '${target.targetTop} mg/dl • $elapsed/${target.duration} min';
  }

  String _activitySubtitle(
    ActivityLogSummaryData activity,
    DateTime now, {
    TemporaryTarget? linkedTarget,
    required AppLocalizations lang,
  }) {
    final isPlanned = _isActivityPlanned(activity, now);
    final durationMinutes = _activityDurationMinutes(activity);
    final parts = <String>[
      _activityName(activity),
      if (isPlanned)
        lang.dashboardActivityStartsIn(
          _remainingMinutes(activity.startedAt, now),
        )
      else
        lang.dashboardActivityElapsed(
          _activityElapsedMinutes(activity.startedAt, now),
        ),
    ];

    if (durationMinutes != null) {
      final endAt = activity.startedAt.add(Duration(minutes: durationMinutes));
      if (isPlanned) {
        parts.add(lang.dashboardActivityDuration(durationMinutes));
      } else {
        final minutesLeft = _remainingMinutes(endAt, now);
        parts.add(
          minutesLeft == 0
              ? lang.dashboardActivityTimePassed
              : lang.dashboardActivityEndsIn(minutesLeft),
        );
      }
    }

    if (linkedTarget != null) {
      parts.add(
        lang.dashboardTargetSubtitle(_targetSubtitle(linkedTarget, now)),
      );
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingActivityAsync = ref.watch(getPendingActivityProvider);
    final targetUi = ref.watch(temporaryTargetUiProvider);
    final nowAsync = ref.watch(timeNowProvider);

    final now = nowAsync.when(
      data: (data) => data,
      error: (_, _) => clock.now(),
      loading: () => clock.now(),
    );

    if (pendingActivityAsync.isLoading) {
      return const SizedBox.shrink();
    }

    final target = _activeTarget(targetUi, now);
    final pendingActivity = pendingActivityAsync.whenOrNull(data: (d) => d);

    final cards = <Widget>[];

    if (pendingActivity != null) {
      final linkedTarget =
          target != null &&
              _isActivityTarget(target) &&
              _isActivityLinkedToTarget(pendingActivity, target)
          ? target
          : null;

      cards.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _StatusInfoCard(
            icon: Icons.directions_run_rounded,
            title: _isActivityPlanned(pendingActivity, now)
                ? context.lang.dashboardPlannedActivityTitle
                : context.lang.dashboardActivityInProgressCardTitle,
            subtitle: _activitySubtitle(
              pendingActivity,
              now,
              linkedTarget: linkedTarget,
              lang: context.lang,
            ),
            trailing: IconButton(
              tooltip: context.lang.dashboardFinishActivityTooltip,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () async {
                await ref.read(stopActivityProvider(pendingActivity).future);
                ref.invalidate(getPendingActivityProvider);
              },
            ),
          ),
        ),
      );
    }

    final targetShownWithActivity =
        target != null &&
        _isActivityTarget(target) &&
        _isActivityLinkedToTarget(pendingActivity, target);

    if (target != null && !targetShownWithActivity) {
      if (_isActivityTarget(target)) {
        cards.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _StatusInfoCard(
              icon: Icons.track_changes_rounded,
              title: context.lang.dashboardActivityTempTargetTitle,
              subtitle: _targetSubtitle(target, now),
              trailing: pendingActivity == null
                  ? FilledButton.icon(
                      onPressed: () async {
                        final activity = await showActivityPickerSheet(context);

                        if (activity == null) return;
                        if (!context.mounted) return;

                        try {
                          await ref.read(
                            insertActivityLogProvider(
                              ActivityLogDraft(
                                activity: activity,
                                startedAt: target.createdAt,
                              ),
                            ).future,
                          );
                          ref.invalidate(getPendingActivityProvider);
                        } catch (e, st) {
                          logE('Activity add failed $e, $st');
                          if (context.mounted) {
                            await showActivityAddFailedDialog(context);
                          }
                          return;
                        }
                      },
                      icon: const Icon(Icons.app_registration),
                      label: Text(context.lang.dashboardAttachActivity),
                    )
                  : null,
            ),
          ),
        );
      }

      if (_isMealTarget(target)) {
        cards.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _StatusInfoCard(
              icon: Icons.restaurant_rounded,
              title: context.lang.dashboardMealTempTargetTitle,
              subtitle: _targetSubtitle(target, now),
            ),
          ),
        );
      }
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> showActivityInProgressDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.lang.dashboardActivityInProgressTitle),
          content: Text(context.lang.dashboardActivityInProgressMessage),
        );
      },
    );
  }

  Future<void> showActivityAddFailedDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.lang.dashboardActivityAddFailedTitle),
          content: Text(context.lang.dashboardActivityAddFailedMessage),
        );
      },
    );
  }
}

class _StatusInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _StatusInfoCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}
