import 'package:flutter/material.dart';
import '../../../../common/l10n/language.dart';
import '../../data/drafts/activity_schedule_draft.dart';
import 'activity_schedule_editor.dart';

class ActivityScheduleSetup extends StatelessWidget {
  const ActivityScheduleSetup({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ActivityScheduleDraft? value;
  final ValueChanged<ActivityScheduleDraft?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.lang.activityScheduleWeekly),
        subtitle: Text(context.lang.activityScheduleDefinitionHint),
        value: value != null,
        onChanged: (enabled) =>
            onChanged(enabled ? ActivityScheduleDraft() : null),
      ),
      if (value != null)
        ActivityScheduleEditor(value: value!, onChanged: onChanged),
    ],
  );
}
