import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_ai_result.dart';
import 'meal_ai_section_card.dart';

class MealAiResultCards extends StatelessWidget {
  final MealAiResult result;
  const MealAiResultCards({super.key, required this.result});
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final titles = {
      'overview': lang.dayAiOverview,
      'before': lang.mealAiBefore,
      'response': lang.mealAiResponse,
      'comparison': lang.mealAiComparison,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in result.sections.entries)
          MealAiSectionCard(title: titles[entry.key]!, section: entry.value),
      ],
    );
  }
}
