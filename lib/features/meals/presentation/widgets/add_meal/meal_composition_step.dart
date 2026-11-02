import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/model/copied_meal_type.dart';
import '../copied_meal_form_field.dart';
import '../meal_ingredients_list_editor.dart';

class MealCompositionStep extends StatelessWidget {
  const MealCompositionStep({
    super.key,
    required this.picker,
    required this.onPicked,
    required this.isCopying,
    this.source,
    this.retrospective = false,
  });
  final Future<CopiedMealType?> Function(BuildContext) picker;
  final Future<bool> Function(CopiedMealType) onPicked;
  final bool isCopying;
  final CopiedMealType? source;
  final bool retrospective;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (retrospective) ...[
        const SizedBox(height: 8),
        Text(context.lang.mealRetrospectiveFullPortionNote),
      ],
      const SizedBox(height: 16),
      CopiedMealFormField(
        initialValue: source,
        picker: picker,
        onPicked: onPicked,
        isLoading: isCopying,
        enabled: !isCopying,
        labelText: context.lang.mealFlowCopy,
      ),
      const SizedBox(height: 16),
      const MealIngredientsListEditor(
        showNutritionSummary: false,
        compact: true,
      ),
    ],
  );
}
