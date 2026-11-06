import 'package:flutter/material.dart';

import '../../../core/domain/model/carbs_label_mode.dart';
import '../../../core/domain/model/net_carbs_calculator.dart';
import '../../l10n/language.dart';
import '../../widgets/meal_macro_summary.dart';

class FamilyIngredientDetailsDialog extends StatelessWidget {
  const FamilyIngredientDetailsDialog({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final reference = data['is_reference'] == 1;
    final fiber = reference ? 0.0 : (data['fiber_per_100g'] as num).toDouble();
    final carbs = calculateNetCarbs(
      carbs: (data['carbs_per_100g'] as num).toDouble(),
      fiber: fiber,
      labelMode: CarbsLabelModeX.fromStorage(
        data['carbs_label_mode'] as String?,
      ),
    );
    return AlertDialog(
      title: Text(data['name'] as String),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width * .8,
        height: MediaQuery.sizeOf(context).height * .5,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reference
                    ? '1 × ${context.lang.mealPortionLabel}'
                    : context.lang.ingredientMacroPer100gTitle,
              ),
              MealMacroSummary(
                netCarbs: carbs,
                fat: (data['fat_per_100g'] as num).toDouble(),
                protein: (data['protein_per_100g'] as num).toDouble(),
                fiber: fiber,
                calories: 0,
                showEnergy: false,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
