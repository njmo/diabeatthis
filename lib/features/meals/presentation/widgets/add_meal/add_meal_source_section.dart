import 'package:flutter/material.dart';

import '../../../../../common/widgets/form_section.dart';
import '../../../data/model/copied_meal_type.dart';
import '../copied_meal_form_field.dart';

class AddMealSourceSection extends StatelessWidget {
  const AddMealSourceSection({
    super.key,
    required this.picker,
    required this.onPicked,
    required this.onSaved,
  });

  final Future<CopiedMealType?> Function(BuildContext context) picker;
  final ValueChanged<CopiedMealType?> onPicked;
  final ValueChanged<CopiedMealType?> onSaved;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.content_copy,
      title: 'Znajdź podobny',
      subtitle:
          'Opcjonalnie skopiuj składniki z podobnego posiłku albo szablonu.',
      children: [
        CopiedMealFormField(
          picker: picker,
          onPicked: onPicked,
          onSaved: onSaved,
        ),
      ],
    );
  }
}
