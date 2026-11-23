import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/planning/activity_catalog_repository.dart';
import '../../../../common/planning/activity_schedule_values.dart';
import '../../../../common/routing/form_route_guard.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../common/widgets/responsive_bottom_sheet.dart';
import '../../../../core/domain/model/activity.dart';
import '../../data/drafts/activity_draft.dart';
import '../../data/drafts/activity_schedule_draft.dart';
import '../../data/providers/activity_provider.dart';
import 'activity_form.dart';
import 'activity_schedule_setup.dart';

Future<Activity?> showActivityDefinitionSheet(
  BuildContext context, {
  ActivityDraft? initialDraft,
  ActivityScheduleDraft? initialSchedule,
}) => showActivityDefinitionEditor<Activity>(
  context,
  initialDraft: initialDraft,
  initialSchedule: initialSchedule,
);

Future<ActivityDraft?> showActivityDefinitionDraftSheet(
  BuildContext context, {
  ActivityDraft? initialDraft,
  ActivityScheduleDraft? initialSchedule,
  ValueChanged<ActivityScheduleDraft?>? onScheduleAccepted,
}) => showActivityDefinitionEditor<ActivityDraft>(
  context,
  draftOnly: true,
  initialDraft: initialDraft,
  initialSchedule: initialSchedule,
  onScheduleAccepted: onScheduleAccepted,
);

Future<T?> showActivityDefinitionEditor<T>(
  BuildContext context, {
  bool draftOnly = false,
  ActivityDraft? initialDraft,
  ActivityScheduleDraft? initialSchedule,
  ValueChanged<ActivityScheduleDraft?>? onScheduleAccepted,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final guard = formRouteGuardOf(context);
  final repository = container
      .read(activityCatalogRepositoryProvider)
      .beginEdit();
  final subscription = container.listen(activityDraftProvider, (_, _) {});
  final previous = container.read(activityDraftProvider);
  final notifier = container.read(activityDraftProvider.notifier);
  if (initialDraft == null) {
    notifier.reset();
  } else {
    notifier.overrideDraft(initialDraft);
  }
  try {
    return await showResponsiveBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (_) => guard(
        UncontrolledProviderScope(
          container: container,
          child: ProviderScope(
            overrides: [
              activityCatalogRepositoryProvider.overrideWithValue(repository),
            ],
            child: ActivityDefinitionSheet(
              draftOnly: draftOnly,
              initialSchedule: initialSchedule,
              onScheduleAccepted: onScheduleAccepted,
            ),
          ),
        ),
      ),
    );
  } finally {
    if (context.mounted) {
      final notifier = container.read(activityDraftProvider.notifier);
      if (previous == null) {
        notifier.reset();
      } else {
        notifier.overrideDraft(previous);
      }
    }
    subscription.close();
  }
}

class ActivityDefinitionSheet extends HookConsumerWidget {
  const ActivityDefinitionSheet({
    super.key,
    this.draftOnly = false,
    this.initialSchedule,
    this.onScheduleAccepted,
  });
  final bool draftOnly;
  final ActivityScheduleDraft? initialSchedule;
  final ValueChanged<ActivityScheduleDraft?>? onScheduleAccepted;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final editing =
        ref
            .watch(activityDraftProvider)
            ?.map(draft: (_) => false, existing: (_) => true) ??
        false;
    final schedule = useState<ActivityScheduleDraft?>(initialSchedule);
    final saving = useState(false);
    final submitted = useState(false);
    final error = useState<String?>(null);
    return KeyboardAwareBottomSheet(
      header: Text(
        editing
            ? context.lang.activityEditTooltip
            : context.lang.activityCreateTitle,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivityForm(
            formKey: formKey,
            autovalidateMode: submitted.value
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            maximumDuration: draftOnly
                ? 1440
                : ref.watch(activityCatalogMaximumDurationProvider),
            trailing: [
              if (!draftOnly || onScheduleAccepted != null) ...[
                const SizedBox(height: 12),
                ActivityScheduleSetup(
                  value: schedule.value,
                  onChanged: (value) {
                    schedule.value = value;
                  },
                ),
              ],
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
                      submitted.value = true;
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      formKey.currentState!.save();
                      final draft = ref.read(activityDraftProvider);
                      final plan = schedule.value;
                      if (draft == null) return;
                      if (plan != null &&
                          !activityScheduleIsValid(
                            plan,
                            duration: draft.durationMinutes,
                            maximumDuration: draftOnly
                                ? 1440
                                : ref.read(
                                    activityCatalogMaximumDurationProvider,
                                  ),
                            cloud:
                                draftOnly ||
                                ref.read(
                                      activityCatalogMaximumDurationProvider,
                                    ) !=
                                    null,
                          )) {
                        error.value = context.lang.activityScheduleInvalid;
                        return;
                      }
                      if (draftOnly) {
                        onScheduleAccepted?.call(plan);
                        Navigator.of(context).pop(draft);
                        return;
                      }
                      saving.value = true;
                      try {
                        final activity = await ref
                            .read(activityCatalogRepositoryProvider)
                            .saveDefinition(draft, schedule: plan);
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
              child: Text(
                editing ? context.lang.settingsSave : context.lang.commonCreate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
