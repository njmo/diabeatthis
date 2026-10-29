import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/duration_minutes_field.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../core/domain/model/activity.dart';
import '../../../../core/drift/database_impl.dart' show ActivityScheduleData;
import '../../data/drafts/activity_schedule_draft.dart';
import '../../data/services/activity_schedule_service.dart';
import 'activity_schedule_editor.dart';

Future<void> showActivityScheduleSheet(
  BuildContext context,
  Activity activity, {
  ActivityScheduleData? rule,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ActivityScheduleSheet(activity: activity, rule: rule),
);

class ActivityScheduleSheet extends HookConsumerWidget {
  const ActivityScheduleSheet({super.key, required this.activity, this.rule});
  final Activity activity;
  final ActivityScheduleData? rule;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(
      rule == null
          ? ActivityScheduleDraft()
          : ActivityScheduleDraft.fromRule(rule!),
    );
    final duration = useTextEditingController(
      text:
          (rule == null ? activity.durationMinutes : rule!.durationMinutes)
              ?.toString() ??
          '',
    );
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final saving = useState(false);
    final error = useState<String?>(null);
    return KeyboardAwareBottomSheet(
      header: Text(
        context.lang.activityScheduleFor(activity.name),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.lang.activityScheduleDefinitionHint),
            const SizedBox(height: 12),
            DurationMinutesField(controller: duration, isRequired: false),
            const SizedBox(height: 12),
            ActivityScheduleEditor(
              value: draft.value,
              onChanged: (value) => draft.value = value,
            ),
            if (error.value != null)
              Text(
                error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving.value
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(context.lang.settingsCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: saving.value
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final value = draft.value;
                      if (value.weekdays.isEmpty ||
                          (value.validUntil != null &&
                              value.validUntil!.isBefore(value.validFrom))) {
                        error.value = context.lang.activityScheduleInvalid;
                        return;
                      }
                      saving.value = true;
                      try {
                        await ref
                            .read(activityScheduleServiceProvider)
                            .save(
                              id: rule?.id,
                              activityId: activity.id,
                              weekdays: value.weekdays,
                              startMinute: value.startMinute,
                              durationMinutes: int.tryParse(
                                duration.text.trim(),
                              ),
                              mode: value.confirmationMode,
                              previousDayMinute: value.previousDayMinute,
                              validFrom: value.validFrom,
                              validUntil: value.validUntil,
                            );
                        if (context.mounted) Navigator.of(context).pop();
                      } catch (_) {
                        if (context.mounted) {
                          error.value = context.lang.activityScheduleSaveFailed;
                        }
                      } finally {
                        if (context.mounted) saving.value = false;
                      }
                    },
              child: Text(context.lang.settingsSave),
            ),
          ),
        ],
      ),
    );
  }
}
