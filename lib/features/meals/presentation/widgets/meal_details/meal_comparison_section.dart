import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_comparison_details.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealComparisonSection extends HookWidget {
  final MealDetailsData details;
  final MealAnalysisData analysis;

  const MealComparisonSection({
    super.key,
    required this.details,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final selected = useState<int?>(null);
    final source = details.copySource;
    final choices = <int, String>{
      if (source != null && source.id != details.meal.id)
        source.id: source.name,
      for (final meal in details.copyUsages)
        if (meal.id != details.meal.id)
          meal.id: '${meal.name} · ${mealDateTime(meal.plannedAt)}',
    };
    if (choices.isEmpty) return const SizedBox.shrink();
    return MealSectionTile(
      title: context.lang.mealReviewCompare,
      children: [
        DropdownButtonFormField<int>(
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.lang.mealReviewChooseComparison,
          ),
          items: [
            for (final choice in choices.entries)
              DropdownMenuItem(
                value: choice.key,
                child: Text(
                  choice.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => selected.value = value,
        ),
        if (selected.value != null)
          MealComparisonDetails(mealId: selected.value!, current: analysis),
      ],
    );
  }
}
