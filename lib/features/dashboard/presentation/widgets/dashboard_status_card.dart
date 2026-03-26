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

class DashboardStatusSection extends ConsumerWidget with Logging {
  const DashboardStatusSection({super.key});

  bool isActivityTarget(TemporaryTarget target) => target.targetTop == 140;
  bool isMealTarget(TemporaryTarget target) => target.targetTop == 90;

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

    Widget? activityWidget;
    if (pendingActivity != null) {
      final minutes = now.difference(pendingActivity.startedAt).inMinutes;
      final activityName =
          pendingActivity.whenOrNull(view: (_, name, _, _, _) => name) ??
              'Aktywność';

      activityWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text('Aktywność: $activityName od $minutes min'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () async {
              await ref.read(stopActivityProvider(pendingActivity).future);
              ref.invalidate(getPendingActivityProvider);
            },
          ),
        ],
      );
    }

    final targetWidget = targetAsync.when(
      loading: () => null,
      error: (_, _) => null,
      data: (target) {
        final elapsed = now.difference(target.createdAt).inMinutes;
        final clampedElapsed = elapsed.clamp(0, target.duration);
        final expired = elapsed >= target.duration;

        if (expired) {
          return const SizedBox.shrink();
        }

        final label = isActivityTarget(target)
            ? 'Target aktywności'
            : isMealTarget(target)
            ? 'Target posiłku'
            : 'Target';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '$label ${target.targetTop} mg/dl aktywny przez '
                    '$clampedElapsed/${target.duration} min',
              ),
            ),
            if (pendingActivity == null && isActivityTarget(target))
              IconButton(
                icon: const Icon(Icons.app_registration),
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
              ),
          ],
        );
      },
    );

    final children = <Widget>[
      if (activityWidget != null) activityWidget,
      if (targetWidget != null) targetWidget,
    ];

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
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