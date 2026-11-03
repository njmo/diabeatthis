import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../activity/common/widgets/activity_start_time_field.dart';
import '../../../activity/data/drafts/activity_log_draft.dart';
import '../../../activity/data/mappers/activity_draft_mapper.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../activity/presentation/widgets/activity_definition_sheet.dart';
import '../../../activity/presentation/widgets/activity_search.dart';

Future<ActivityLogDraft?> showActivityTargetAttachmentSheet(
  BuildContext context,
) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(activityDraftProvider.notifier).reset();
  return showModalBottomSheet<ActivityLogDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ActivityTargetAttachmentSheet(),
  );
}

class ActivityTargetAttachmentSheet extends HookConsumerWidget {
  const ActivityTargetAttachmentSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = useState<DateTime?>(null);
    final activity = ref.watch(activityDraftProvider);
    return KeyboardAwareBottomSheet(
      header: Text(
        context.lang.dashboardAttachActivity,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ActivitySearch(),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.lang.activityCreateTitle),
            onPressed: () async {
              final created = await showActivityDefinitionSheet(context);
              if (created != null && context.mounted) {
                ref
                    .read(activityDraftProvider.notifier)
                    .overrideDraft(created.toDraft());
              }
            },
          ),
          const SizedBox(height: 16),
          ActivityStartTimeField(
            value: start.value,
            onChanged: (value) => start.value = value,
          ),
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.lang.settingsCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: activity == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      ActivityLogDraft(
                        activity: activity,
                        startedAt: start.value ?? clock.now(),
                      ),
                    ),
              child: Text(context.lang.commonPick),
            ),
          ),
        ],
      ),
    );
  }
}
