import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/drift/database_impl.dart';

class ActivityScheduleCard extends StatelessWidget {
  const ActivityScheduleCard({
    super.key,
    required this.rule,
    required this.name,
    required this.onEnabled,
    required this.onEdit,
    this.onDelete,
  });
  final ActivityScheduleData rule;
  final String name;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final days = rule.weekdays
        .split(',')
        .map(
          (day) => DateFormat.E(
            context.lang.localeName,
          ).format(DateTime(2024, 1, int.parse(day))),
        )
        .join(', ');
    final mode = switch (rule.confirmationMode) {
      'automatic' => context.lang.activityScheduleAutomatic,
      'previous_day' => context.lang.activitySchedulePrevious,
      _ => context.lang.activityScheduleBefore,
    };
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(name),
            subtitle: Text(
              '$days · ${TimeOfDay(hour: rule.startMinute ~/ 60, minute: rule.startMinute % 60).format(context)}\n$mode',
            ),
            value: rule.enabled,
            onChanged: onEnabled,
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: onEdit,
                child: Text(context.lang.activityScheduleEditFuture),
              ),
              if (onDelete != null)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.lang.activityScheduleDelete),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
