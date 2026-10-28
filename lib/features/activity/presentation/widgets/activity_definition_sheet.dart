import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../core/domain/model/activity.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../data/drafts/activity_schedule_draft.dart';
import '../../data/providers/activity_provider.dart';
import '../../data/services/activity_schedule_service.dart';
import 'activity_form.dart';
import 'activity_schedule_setup.dart';

Future<Activity?> showActivityDefinitionSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final previous = container.read(activityDraftProvider);
  container.read(activityDraftProvider.notifier).reset();
  try {
    return await showModalBottomSheet<Activity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ActivityDefinitionSheet(),
    );
  } finally {
    final notifier = container.read(activityDraftProvider.notifier);
    if (previous == null) {
      notifier.reset();
    } else {
      notifier.overrideDraft(previous);
    }
  }
}

class ActivityDefinitionSheet extends HookConsumerWidget {
  const ActivityDefinitionSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final schedule = useState<ActivityScheduleDraft?>(null);
    final saving = useState(false);
    final error = useState<String?>(null);
    return KeyboardAwareBottomSheet(
      header: Text(
        context.lang.activityCreateTitle,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivityForm(
            formKey: formKey,
            trailing: [
              const SizedBox(height: 12),
              ActivityScheduleSetup(
                value: schedule.value,
                onChanged: (value) {
                  schedule.value = value;
                  if (value != null) {
                    ref
                        .read(activityDraftProvider.notifier)
                        .setHasPlannedDuration(true);
                  }
                },
              ),
            ],
          ),
          if (error.value != null)
            Text(
              error.value!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
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
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      formKey.currentState!.save();
                      final draft = ref.read(activityDraftProvider);
                      final plan = schedule.value;
                      if (draft == null) return;
                      if (plan != null &&
                          (plan.weekdays.isEmpty ||
                              draft.durationMinutes == null ||
                              (plan.validUntil != null &&
                                  plan.validUntil!.isBefore(plan.validFrom)))) {
                        error.value = context.lang.activityScheduleInvalid;
                        return;
                      }
                      saving.value = true;
                      try {
                        final db = ref.read(databaseProvider);
                        final activity = await db.transaction(() async {
                          final activity = await saveActivityDraft(db, draft);
                          if (activity == null) {
                            throw StateError('Could not create activity');
                          }
                          if (plan != null) {
                            await ref
                                .read(activityScheduleServiceProvider)
                                .save(
                                  activityId: activity.id,
                                  weekdays: plan.weekdays,
                                  startMinute: plan.startMinute,
                                  durationMinutes: activity.durationMinutes!,
                                  mode: plan.confirmationMode,
                                  previousDayMinute: plan.previousDayMinute,
                                  validFrom: plan.validFrom,
                                  validUntil: plan.validUntil,
                                );
                          }
                          return activity;
                        });
                        if (context.mounted) {
                          Navigator.of(context).pop(activity);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          error.value = context.lang.activityScheduleSaveFailed;
                        }
                      } finally {
                        if (context.mounted) saving.value = false;
                      }
                    },
              child: Text(context.lang.commonCreate),
            ),
          ),
        ],
      ),
    );
  }
}
