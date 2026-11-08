import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/language.dart';
import '../../demo/meal_decision_demo_caregiver.dart';
import '../../demo/meal_decision_demo_controller.dart';

class MealDecisionDemoTransferButton extends ConsumerWidget {
  const MealDecisionDemoTransferButton({
    super.key,
    required this.requestKey,
    required this.requestId,
    required this.caregiverId,
  });
  final String requestKey, requestId, caregiverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = ref
        .watch(mealDecisionDemoCaregiversProvider)
        .where((person) => person.id != caregiverId)
        .toList();
    return OutlinedButton.icon(
      icon: const Icon(Icons.forward_to_inbox_outlined),
      label: Text(context.lang.mealDecisionDemoTransfer),
      onPressed: others.isEmpty
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (dialogContext) => SimpleDialog(
                title: Text(context.lang.mealDecisionDemoTransfer),
                children: [
                  for (final person in others)
                    SimpleDialogOption(
                      onPressed: () {
                        ref
                            .read(mealDecisionDemoControllerProvider.notifier)
                            .transfer(
                              requestKey,
                              requestId,
                              caregiverId,
                              person.id,
                            );
                        Navigator.of(dialogContext).pop();
                      },
                      child: Text(person.name),
                    ),
                ],
              ),
            ),
    );
  }
}
