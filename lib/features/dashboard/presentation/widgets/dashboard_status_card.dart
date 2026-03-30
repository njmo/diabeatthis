import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/model/activity.dart';
import '../../../../core/domain/model/activity_log.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/logger/logger.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../activity/presentation/widgets/activity_picker_dialog.dart';
import '../../data/providers/temporary_target_provider.dart';
import '../../data/providers/time_now_provider.dart';

class DashboardStatusCard extends ConsumerWidget with Logging {
  const DashboardStatusCard({super.key});

  static const int activityTargetValue = 140;
  static const int mealTargetValue = 90;

  bool _isActivityTarget(TemporaryTarget target) =>
      target.targetTop == activityTargetValue;

  bool _isMealTarget(TemporaryTarget target) =>
      target.targetTop == mealTargetValue;

  bool _isTargetExpired(TemporaryTarget target, DateTime now) {
    final elapsed = now.difference(target.createdAt).inMinutes;
    return elapsed >= target.duration;
  }

  int _elapsedMinutes(TemporaryTarget target, DateTime now) {
    final elapsed = now.difference(target.createdAt).inMinutes;
    return elapsed.clamp(0, target.duration);
  }

  bool _isActivityLinkedToTarget(dynamic pendingActivity, TemporaryTarget target) {
    if (pendingActivity == null) return false;

    return pendingActivity.startedAt == target.createdAt;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingActivityAsync = ref.watch(getPendingActivityProvider);
    final targetAsync = ref.watch(temporaryTargetStreamProvider);
    final nowAsync = ref.watch(timeNowProvider);

    final now = nowAsync.when(
      data: (data) => data,
      error: (_, _) => clock.now(),
      loading: () => clock.now(),
    );

    final pendingActivity = pendingActivityAsync.whenOrNull(data: (d) => d);

    final target = targetAsync.whenOrNull(
      data: (t) {
        if (_isTargetExpired(t, now)) return null;
        return t;
      },
    );

    if (pendingActivityAsync.isLoading && targetAsync.isLoading) {
      return const _StatusInfoCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Ładowanie statusu...',
        subtitle: null,
        trailing: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (target != null &&
        _isActivityTarget(target) &&
        _isActivityLinkedToTarget(pendingActivity, target)) {
      final targetMinutes = _elapsedMinutes(target, now);
      final activityMinutes = now.difference(pendingActivity!.startedAt).inMinutes;
      final activityName =
          pendingActivity.whenOrNull(view: (_, name, _, _, _) => name) ??
              'Aktywność';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _StatusInfoCard(
          icon: Icons.directions_run_rounded,
          title: 'Aktywność w toku',
          subtitle:
          '$activityName • target $activityTargetValue mg/dl • '
              '$activityMinutes min ($targetMinutes/${target.duration} min targetu)',
          trailing: IconButton(
            tooltip: 'Zakończ aktywność',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () async {
              await ref.read(stopActivityProvider(pendingActivity).future);
              ref.invalidate(getPendingActivityProvider);
            },
          ),
        ),
      );
    }

    if (target != null && _isActivityTarget(target)) {
      final minutes = _elapsedMinutes(target, now);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _StatusInfoCard(
          icon: Icons.track_changes_rounded,
          title: 'Target aktywności aktywny',
          subtitle: '$activityTargetValue mg/dl • $minutes/${target.duration} min',
          trailing: FilledButton.icon(
            onPressed: () async {
              final activity = await showDialog<Activity?>(
                barrierDismissible: true,
                context: context,
                builder: (context) => const ActivityPickerDialog(),
              );

              if (activity == null) return;

              final controller = ref.read(activityControllerProvider.notifier);

              Activity? act;
              try {
                act = await controller.saveActivity(activity);
                if (act == null) {
                  throw Exception('Something went wrong with adding activity');
                }
              } catch (e, st) {
                logE('Błąd dodawania aktywności $e, $st');
                if (context.mounted) {
                  await showActivityAddFailedDialog(context);
                }
                return;
              }

              await act.whenOrNull(
                existing: (id, name, pre, post) async {
                  logI('Starting activity: $id $name');
                  try {
                    await ref.read(
                      insertActivityLogProvider(
                        ActivityLog.draft(
                          activityId: id,
                          startedAt: target.createdAt,
                        ),
                      ).future,
                    );
                    ref.invalidate(getPendingActivityProvider);
                  } catch (_) {
                    if (context.mounted) {
                      await showActivityInProgressDialog(context);
                    }
                  }
                },
              );
            },
            icon: const Icon(Icons.app_registration),
            label: const Text('Podepnij aktywność'),
          ),
        ),
      );
    }

    if (target != null && _isMealTarget(target)) {
      final minutes = _elapsedMinutes(target, now);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _StatusInfoCard(
          icon: Icons.restaurant_rounded,
          title: 'Meal target aktywny',
          subtitle: '$mealTargetValue mg/dl • $minutes/${target.duration} min',
        ),
      );
    }

    if (pendingActivity != null) {
      final minutes = now.difference(pendingActivity.startedAt).inMinutes;
      final activityName =
          pendingActivity.whenOrNull(view: (_, name, _, _, _) => name) ??
              'Aktywność';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _StatusInfoCard(
          icon: Icons.directions_run_rounded,
          title: 'Aktywność w toku',
          subtitle: '$activityName • $minutes min',
          trailing: IconButton(
            tooltip: 'Zakończ aktywność',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () async {
              await ref.read(stopActivityProvider(pendingActivity).future);
              ref.invalidate(getPendingActivityProvider);
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> showActivityInProgressDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aktywność w toku'),
          content: const Text(
            'Jedna aktywność jest już w trakcie.\n\n'
                'Nie można rozpocząć nowej, dopóki obecna nie zostanie zakończona.',
          ),
        );
      },
    );
  }

  Future<void> showActivityAddFailedDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Problem z dodaniem aktywności'),
          content: const Text(
            'Taka aktywność już istnieje lub parametry nie są podane prawidłowo.\n'
                'Pamiętaj: pre i post muszą być <100 i >0.',
          ),
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
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
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
              child: Icon(
                icon,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
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
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}