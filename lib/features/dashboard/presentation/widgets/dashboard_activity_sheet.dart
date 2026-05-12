import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/date_time_picker.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../core/domain/model/activity.dart';
import '../../../activity/presentation/widgets/activity_picker_sheet.dart';

class DashboardActivityAction {
  const DashboardActivityAction({
    required this.activity,
    required this.startedAt,
    required this.isScheduled,
  });

  final Activity activity;
  final DateTime startedAt;
  final bool isScheduled;
}

class DashboardActivitySheet extends HookConsumerWidget {
  const DashboardActivitySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedActivity = useState<Activity?>(null);
    final scheduled = useState(false);
    final startAt = useState(clock.now());
    final selected = selectedActivity.value;

    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              'Dodaj aktywność',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Zamknij',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected == null)
            OutlinedButton.icon(
              onPressed: () async {
                final activity = await showActivityPickerSheet(context);
                if (!context.mounted) {
                  return;
                }
                if (activity != null) {
                  selectedActivity.value = activity;
                }
              },
              icon: const Icon(Icons.search),
              label: const Text('Wybierz aktywność'),
            )
          else
            SelectedDashboardActivityCard(
              activity: selected,
              onChange: () async {
                final activity = await showActivityPickerSheet(context);
                if (!context.mounted) {
                  return;
                }
                if (activity != null) {
                  selectedActivity.value = activity;
                }
              },
            ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: scheduled.value,
            onChanged: (value) {
              scheduled.value = value ?? false;
              startAt.value = _todayAt(startAt.value);
            },
            title: const Text('Zaplanuj na później'),
            subtitle: const Text('Wybierz godzinę startu na dzisiaj'),
          ),
          if (scheduled.value) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTodayTimePicker(
                  context: context,
                  initialDate: startAt.value,
                );
                if (picked != null) {
                  startAt.value = picked;
                }
              },
              icon: const Icon(Icons.schedule),
              label: Text('Start o ${_formatTime(startAt.value)}'),
            ),
          ],
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: selected == null
                  ? null
                  : () {
                      final startedAt = scheduled.value
                          ? _todayAt(startAt.value)
                          : clock.now();
                      Navigator.of(context).pop(
                        DashboardActivityAction(
                          activity: selected,
                          startedAt: startedAt,
                          isScheduled: scheduled.value,
                        ),
                      );
                    },
              icon: Icon(
                scheduled.value ? Icons.event_available : Icons.play_arrow,
              ),
              label: Text(scheduled.value ? 'Zaplanuj' : 'Wystartuj'),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _todayAt(DateTime date) {
    final today = clock.now();
    return DateTime(today.year, today.month, today.day, date.hour, date.minute);
  }

  static String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class SelectedDashboardActivityCard extends StatelessWidget {
  const SelectedDashboardActivityCard({
    super.key,
    required this.activity,
    required this.onChange,
  });

  final Activity activity;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _activityName(activity);
    final duration = _activityDurationMinutes(activity);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_run,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(duration),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Zmień aktywność',
              onPressed: onChange,
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }

  static String _activityName(Activity activity) {
    return activity.when(
      existing: (_, name, _, _, _) => name,
      draft: (name, _, _, _) => name,
      empty: () => 'Aktywność',
    );
  }

  static int? _activityDurationMinutes(Activity activity) {
    return activity.when(
      existing: (_, _, _, _, durationMinutes) => durationMinutes,
      draft: (_, _, _, durationMinutes) => durationMinutes,
      empty: () => null,
    );
  }

  static String _formatDuration(int? minutes) {
    if (minutes == null) {
      return 'Zakończenie ręczne';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes.remainder(60);
    if (hours == 0) {
      return 'Planowany czas: $minutes min';
    }
    if (remainingMinutes == 0) {
      return 'Planowany czas: ${hours}h';
    }
    return 'Planowany czas: ${hours}h ${remainingMinutes.toString().padLeft(2, '0')} min';
  }
}
