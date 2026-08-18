import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';

class MealTransitionAnalysisSection extends StatelessWidget {
  final MealDetailsData details;

  const MealTransitionAnalysisSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final transitions = details.statusTransitions;

    return MealSectionTile(
      title: context.lang.mealTransitionTitle,
      children: [
        if (transitions.isEmpty)
          MealInfoRow(label: context.lang.mealStatusHistoryLabel, value: '-')
        else
          for (final transition in transitions)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                mealStatusIcon(transition.toStatus),
                color: transition.isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(_transitionLabel(context, transition)),
              subtitle: Text(mealDateTime(transition.timestamp)),
              trailing: transition.isCurrent
                  ? MealSmallBadge(label: context.lang.mealCurrentBadge)
                  : null,
            ),
      ],
    );
  }

  String _transitionLabel(
    BuildContext context,
    MealStatusTransitionData transition,
  ) {
    final from = transition.fromStatus;
    if (from == null) {
      return context.lang.mealInitialStatus(
        mealStatusLabel(transition.toStatus),
      );
    }
    if (from == transition.toStatus) {
      return mealStatusLabel(transition.toStatus);
    }
    return '${mealStatusLabel(from)} → ${mealStatusLabel(transition.toStatus)}';
  }
}
