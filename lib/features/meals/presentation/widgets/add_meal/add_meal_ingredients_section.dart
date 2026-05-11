import 'package:flutter/material.dart';

import '../../../../../common/widgets/form_section.dart';
import '../meal_ingredients_list_editor.dart';

class AddMealIngredientsSection extends StatelessWidget {
  const AddMealIngredientsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const FormSection(
      icon: Icons.list_alt,
      title: 'Składniki',
      subtitle: 'Dodaj składniki i sprawdź podsumowanie makroskładników.',
      children: [MealIngredientsListEditor()],
    );
  }
}
