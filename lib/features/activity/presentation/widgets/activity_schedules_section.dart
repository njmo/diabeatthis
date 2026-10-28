import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/activity.dart';
import '../../data/services/activity_schedule_service.dart';
import 'activity_schedule_card.dart';
import 'activity_schedule_sheet.dart';

class ActivitySchedulesSection extends ConsumerWidget {
  const ActivitySchedulesSection({super.key, required this.activity});
  final Activity activity;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(activitySchedulesProvider);
    Future<void> perform(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.lang.activityScheduleSaveFailed)),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.activityScheduleTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(context.lang.activityScheduleDefinitionHint),
        schedules.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(context.lang.activityScheduleSaveFailed),
          data: (rules) => Column(
            children: rules
                .where((rule) => rule.activityId == activity.id)
                .map(
                  (rule) => ActivityScheduleCard(
                    rule: rule,
                    name: activity.name,
                    onEnabled: (value) => perform(
                      () => ref
                          .read(activityScheduleServiceProvider)
                          .setEnabled(rule, value),
                    ),
                    onEdit: () => showActivityScheduleSheet(
                      context,
                      activity,
                      rule: rule,
                    ),
                    onDelete: () => perform(
                      () => ref
                          .read(activityScheduleServiceProvider)
                          .removeSchedule(rule.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text(context.lang.activityScheduleAdd),
          onPressed: () => showActivityScheduleSheet(context, activity),
        ),
      ],
    );
  }
}
