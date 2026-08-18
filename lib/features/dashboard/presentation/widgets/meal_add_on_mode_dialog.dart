import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'meal_status_dialog_result.dart';

class MealAddOnModeDialog extends StatelessWidget {
  const MealAddOnModeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.lang.mealSummaryExtraTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.looks_one_outlined),
            title: Text(context.lang.mealAddOnOneAndHalf),
            onTap: () =>
                Navigator.of(context).pop(MealAddOnChoice.oneAndHalfPortion),
          ),
          ListTile(
            leading: const Icon(Icons.looks_two_outlined),
            title: Text(context.lang.mealAddOnDouble),
            onTap: () =>
                Navigator.of(context).pop(MealAddOnChoice.doublePortion),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(context.lang.mealAddOnAdvanced),
            subtitle: Text(context.lang.mealAddOnAdvancedSubtitle),
            onTap: () => Navigator.of(context).pop(MealAddOnChoice.advanced),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.lang.settingsCancel),
        ),
      ],
    );
  }
}
