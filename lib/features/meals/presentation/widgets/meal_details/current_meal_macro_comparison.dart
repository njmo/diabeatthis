import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../common/widgets/meal_macro_comparison.dart';
import '../../../data/models/meal_details_data.dart';

class CurrentMealMacroComparison extends StatelessWidget {
  final MealDetailsData details;
  const CurrentMealMacroComparison({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final snapshot = details.preferredSummarySnapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final lang = context.lang;
    return DetailSectionCard(
      title:
          '${lang.mealComparisonCurrent} · ${details.consumedSnapshot != null ? lang.similarMealsConsumed : lang.similarMealsPlanned}',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: MealMacroComparison(
            netCarbs: snapshot.totalNetCarbsG,
            protein: snapshot.totalProteinG,
            fat: snapshot.totalFatG,
            showRatio: true,
          ),
        ),
      ],
    );
  }
}
