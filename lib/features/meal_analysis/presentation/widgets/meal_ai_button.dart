import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'meal_ai_sheet.dart';

class MealAiButton extends StatelessWidget {
  final int mealId;
  final String name;
  const MealAiButton({super.key, required this.mealId, required this.name});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.lang.mealAiTitle,
    icon: const Icon(Icons.auto_awesome),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: MealAiSheet(mealId: mealId, name: name),
      ),
    ),
  );
}
