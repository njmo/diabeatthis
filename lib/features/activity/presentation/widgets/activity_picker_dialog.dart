import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/providers/activity_provider.dart';
import 'activity_form.dart';
import 'activity_search.dart';

class ActivityPickerDialog extends ConsumerWidget {
  const ActivityPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityDialogControllerProvider);
    final c = ref.read(activityDialogControllerProvider.notifier);

    return AlertDialog(
      title: Row(
        children: [
          switch (state) {
            ActivityDialogStep.search => const Text('Wybierz aktywnosc'),
            ActivityDialogStep.add => const Text('Nowa aktywnosc'),
            ActivityDialogStep.confirm => const Text('Potwierdz aktywnosc'),
          },
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: switch (state) {
                ActivityDialogStep.search => const Icon(Icons.add),
                ActivityDialogStep.add => const Icon(Icons.search),
                ActivityDialogStep.confirm => const Icon(Icons.search),
              },
              onPressed: () {
                c.toOppositeState();
              },
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 250,
        child: switch (state) {
          ActivityDialogStep.search => const ActivitySearch(),
          ActivityDialogStep.add => const ActivityForm(),
          ActivityDialogStep.confirm => const Text('Start'),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ref.read(activityDraftProvider)),
          child: const Text('Wybierz'),
        ),
      ],
    );
  }
}
