import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/form_section.dart';
import '../../../data/model/copied_meal_type.dart';
import '../copied_meal_form_field.dart';

class AddMealSourceSection extends StatelessWidget {
  const AddMealSourceSection({
    super.key,
    required this.picker,
    required this.onPicked,
  });

  final Future<CopiedMealType?> Function(BuildContext context) picker;
  final Future<bool> Function(CopiedMealType) onPicked;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.content_copy,
      title: context.lang.addMealSourceTitle,
      subtitle: context.lang.addMealSourceSubtitle,
      children: [CopiedMealFormField(picker: picker, onPicked: onPicked)],
    );
  }
}
