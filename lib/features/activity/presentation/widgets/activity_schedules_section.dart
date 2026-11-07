import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/activity.dart';
import '../../../../core/drift/database_impl.dart' show ActivityScheduleData;
import '../../data/services/activity_schedule_service.dart';
import 'activity_schedule_card.dart';
import 'activity_schedule_sheet.dart';

class ActivitySchedulesSection extends ConsumerWidget {
  const ActivitySchedulesSection({super.key, required this.activity})
    : rules = null,
      onAdd = null,
      changeEnabled = null,
      canChangeEnabled = null;
  final Activity activity;
  const ActivitySchedulesSection.controlled({
    super.key,
    required this.activity,
    required this.rules,
    required this.onAdd,
    this.changeEnabled,
    this.canChangeEnabled,
  });
  final List<ActivityScheduleData>? rules;
  final VoidCallback? onAdd;
  final Future<void> Function(ActivityScheduleData, bool)? changeEnabled;
  final bool Function(ActivityScheduleData)? canChangeEnabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = rules == null
        ? ref.watch(activitySchedulesProvider)
        : AsyncData(rules!);
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
                    onEnabled: this.rules != null
                        ? (changeEnabled == null ||
                                  canChangeEnabled?.call(rule) == false
                              ? null
                              : (value) =>
                                    perform(() => changeEnabled!(rule, value)))
                        : (value) => perform(
                            () => ref
                                .read(activityScheduleServiceProvider)
                                .setEnabled(rule, value),
                          ),
                    onEdit: this.rules != null
                        ? null
                        : () => showActivityScheduleSheet(
                            context,
                            activity,
                            rule: rule,
                          ),
                    onDelete: this.rules != null
                        ? null
                        : () => perform(
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
          onPressed:
              onAdd ?? () => showActivityScheduleSheet(context, activity),
        ),
      ],
    );
  }
}
