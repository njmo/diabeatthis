import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/drafts/activity_draft.dart';
import '../../data/providers/activity_provider.dart';
import 'activity_form.dart';
import 'activity_search.dart';

Future<ActivityDraft?> showActivityPickerSheet(BuildContext context) {
  return showModalBottomSheet<ActivityDraft?>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => const ActivityPickerSheet(),
  );
}

class ActivityPickerSheet extends HookConsumerWidget {
  const ActivityPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAutofocus = useState(false);
    final state = ref.watch(activityDialogControllerProvider);
    final controller = ref.read(activityDialogControllerProvider.notifier);
    final canPick = state == ActivityPickerStep.add
        ? true
        : ref.watch(activityDraftProvider) != null;
    final isInitial = state == ActivityPickerStep.initial;
    final isAdding = state == ActivityPickerStep.add;
    final isSearching = state == ActivityPickerStep.search;

    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(switch (state) {
              ActivityPickerStep.initial => 'Dodaj aktywność',
              ActivityPickerStep.add => 'Utwórz aktywność',
              ActivityPickerStep.search => 'Wybierz aktywność',
            }, style: Theme.of(context).textTheme.titleLarge),
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
          SegmentedButton<ActivityPickerStep>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ActivityPickerStep.search,
                icon: Icon(Icons.search),
                label: Text('Wyszukaj'),
              ),
              ButtonSegment(
                value: ActivityPickerStep.add,
                icon: Icon(Icons.add),
                label: Text('Utwórz'),
              ),
            ],
            selected: isInitial ? const {} : {state},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) {
                return;
              }
              final next = selection.first;
              if (next == ActivityPickerStep.add) {
                searchAutofocus.value = false;
                ref.read(activityDraftProvider.notifier).reset();
                controller.addState();
              } else {
                searchAutofocus.value = true;
                controller.searchState();
              }
            },
          ),
          const SizedBox(height: 16),
          if (isInitial)
            const ActivitySearch(showSearchField: false)
          else if (isAdding)
            const ActivityForm()
          else if (isSearching)
            ActivitySearch(autofocus: searchAutofocus.value),
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
              onPressed: canPick
                  ? () {
                      if (isAdding) {
                        final formState = ref
                            .read(mealIngredientFormKeyProvider)
                            .currentState;
                        if (!(formState?.validate() ?? false)) {
                          return;
                        }
                        formState?.save();
                      }
                      Navigator.of(
                        context,
                      ).pop(ref.read(activityDraftProvider));
                    }
                  : null,
              icon: Icon(isAdding ? Icons.add : Icons.check),
              label: Text(isAdding ? 'Utwórz' : 'Wybierz'),
            ),
          ),
        ],
      ),
    );
  }
}
