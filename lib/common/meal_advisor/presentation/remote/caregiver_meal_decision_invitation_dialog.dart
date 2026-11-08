import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../../widgets/icon_choice_pair.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';

class CaregiverMealDecisionInvitationDialog extends StatelessWidget {
  const CaregiverMealDecisionInvitationDialog({
    super.key,
    required this.name,
    required this.busy,
    required this.failed,
    required this.onAccept,
    required this.onCancel,
  });

  final String name;
  final bool busy;
  final bool failed;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: MealStartSheet(
      title: context.lang.mealDecisionInvitation(name),
      subtitle: '',
      showClose: false,
      maxHeightFactor: .75,
      body: IconChoicePair(
        firstIcon: Icons.check_rounded,
        firstLabel: context.lang.mealDecisionInvitationAccept,
        onFirst: busy ? null : onAccept,
        secondIcon: Icons.close_rounded,
        secondLabel: context.lang.commonCancel,
        onSecond: busy ? null : onCancel,
      ),
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (failed)
            Text(
              context.lang.mealDecisionRemoteFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}
