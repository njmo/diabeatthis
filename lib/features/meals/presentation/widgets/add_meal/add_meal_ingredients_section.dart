import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/form_section.dart';
import '../meal_ingredients_list_editor.dart';

class AddMealIngredientsSection extends StatelessWidget {
  const AddMealIngredientsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.list_alt,
      title: context.lang.addMealIngredientsTitle,
      subtitle: context.lang.addMealIngredientsSubtitle,
      children: const [MealIngredientsListEditor()],
    );
  }
}
