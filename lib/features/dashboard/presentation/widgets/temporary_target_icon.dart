import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/model/activity.dart';
import '../../../../core/domain/model/activity_log.dart';
import '../../../../core/logger/logger.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../activity/presentation/widgets/activity_picker_dialog.dart';
import '../../data/providers/temporary_target_provider.dart';
import '../../data/providers/time_now_provider.dart';

class TemporaryTargetIcon extends ConsumerWidget with Logging {
  const TemporaryTargetIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(temporaryTargetStreamProvider);
    final nowAsync = ref.watch(timeNowProvider);
    final pendingActivity = ref.watch(getPendingActivityProvider);

    final activityInProgress = pendingActivity.whenOrNull(
      data: (d) => d != null,
      error: (_, __) => false,
      loading: () => false,
    );

    return targetAsync.when(
      loading: () => const Text('Ładowanie...'),
      error: (e, _) => SizedBox.shrink(),
      data: (target) {
        final now = nowAsync.when(
          data: (data) => data,
          error: (_, _) => clock.now(),
          loading: () => clock.now(),
        );
        final elapsed = now.difference(target.createdAt).inMinutes;
        final clampedElapsed = elapsed.clamp(0, target.duration);
        final expired = elapsed >= target.duration;

        if (expired) {
          return const Text('Target zakończony');
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Target ${target.targetTop}mg/dl aktywny przez $clampedElapsed/${target.duration} min',
            ),
            if (!activityInProgress!)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.app_registration),
                  onPressed: () async {
                    final activity = await showDialog<Activity?>(
                      barrierDismissible: true,
                      context: context,
                      builder: (context) => ActivityPickerDialog(),
                    );
                    if (activity != null) {
                      final c = ref.read(activityControllerProvider.notifier);
                      Activity? act;
                      try {
                        act = await c.saveActivity(activity);
                        if (act == null) {
                          throw Exception(
                            'Something went wrong with adding activity',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showActivityAddFailedDialog(context);
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
                          } catch (e) {
                            if (context.mounted) {
                              showActivityInProgressDialog(context);
                            }
                          }
                        },
                      );
                    }
                  },
                ),
              ),
          ],
        );
      },
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
          title: const Text('Problem z dodaniem aktywnosci'),
          content: const Text(
            'Taka aktywnosc juz istnieje lub parametry nie sa podane prawidlowo.\n'
            'pamietaj pre i post musza byc <100 i >0',
          ),
        );
      },
    );
  }
}
