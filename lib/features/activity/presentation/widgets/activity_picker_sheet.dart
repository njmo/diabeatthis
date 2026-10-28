import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../data/drafts/activity_draft.dart';
import '../../data/mappers/activity_draft_mapper.dart';
import '../../data/providers/activity_provider.dart';
import 'activity_definition_sheet.dart';
import 'activity_search.dart';

Future<ActivityDraft?> showActivityPickerSheet(BuildContext context) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(activityDraftProvider.notifier).reset();
  return showModalBottomSheet<ActivityDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ActivityPickerSheet(),
  );
}

class ActivityPickerSheet extends ConsumerWidget {
  const ActivityPickerSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => KeyboardAwareBottomSheet(
    header: Text(
      context.lang.activityPickTitle,
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
            final activity = await showActivityDefinitionSheet(context);
            if (activity != null && context.mounted) {
              Navigator.of(context).pop(activity.toDraft());
            }
          },
        ),
      ],
    ),
    actions: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.lang.settingsCancel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: ref.watch(activityDraftProvider) == null
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(ref.read(activityDraftProvider)),
            child: Text(context.lang.commonPick),
          ),
        ),
      ],
    ),
  );
}
