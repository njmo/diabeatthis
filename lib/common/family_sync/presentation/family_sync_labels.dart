import 'package:flutter/widgets.dart';

import '../../l10n/language.dart';

String familySyncIntegrationLabel(BuildContext context, String kind) =>
    switch (kind) {
      'ingredients' => context.lang.familySyncIngredients,
      'ingredientHistory' => context.lang.familySyncIngredientHistory,
      'portions' => context.lang.familySyncPortions,
      'ingredientPortions' => context.lang.familySyncIngredientPortions,
      'ingredientOrigins' => context.lang.familySyncIngredientOrigins,
      'meals' => context.lang.familySyncMeals,
      'mealIngredients' => context.lang.familySyncMealIngredients,
      'mealHistory' => context.lang.familySyncMealHistory,
      'mealSnapshots' => context.lang.familySyncMealSnapshots,
      'activities' => context.lang.familySyncActivities,
      'activitySchedules' => context.lang.familySyncActivitySchedules,
      'activityOccurrences' => context.lang.familySyncActivityOccurrences,
      'activityLogs' => context.lang.familySyncActivityLogs,
      'mealTemplates' => context.lang.familySyncMealTemplates,
      'mealTemplateIngredients' => context.lang.familySyncTemplateIngredients,
      _ => throw ArgumentError.value(kind, 'kind'),
    };
