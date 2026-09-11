import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../models/meal_page_state.dart';
import 'meal_basic_info_section.dart';
import 'meal_copy_relations_section.dart';
import 'meal_history_status.dart';
import 'meal_transition_analysis_section.dart';

/// Record diagnostics remain available without dominating the meal analysis.
class MealTechnicalSection extends StatelessWidget {
  final MealPageState state;
  const MealTechnicalSection({super.key, required this.state});

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: ExpansionTile(
      leading: const Icon(Icons.info_outline_rounded),
      title: Text(context.lang.mealTechnicalTitle),
      subtitle: Text(context.lang.mealTechnicalSubtitle),
      childrenPadding: const EdgeInsets.all(8),
      children: [
        if (state.details.meal.isEaten)
          MealHistoryStatus(analysis: state.analysis),
        MealCopyRelationsSection(details: state.details),
        MealBasicInfoSection(details: state.details),
        MealTransitionAnalysisSection(details: state.details),
      ],
    ),
  );
}
